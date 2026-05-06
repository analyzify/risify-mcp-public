# Flow: Navigation Management

Manage Breadcrumbs, Similar (collections & products), and Discover suggestions for Shopify products and collections. Includes AI-powered suggestions and bulk generation.

> **UI labels vs metafield keys:** the UI uses "Discover" (formerly "Related Searches") and "Similar" (formerly "Collection Menu"). Metafield keys keep their original names — `related_searches`, `collection_menu`, `related_products`. **Always speak the UI label to the user; use the metafield key only in queries.** Old names ("Related Searches", "Collection Menu") MUST NOT appear in user-facing strings.

## Architecture

Navigation data is stored as **Shopify metafields** on products and collections:

| UI label | Metafield Key | Type | Applies To |
|---------|--------------|------|------------|
| Breadcrumbs | `$app:risify.breadcrumb` | `list.collection_reference` | Products & Collections |
| Breadcrumbs custom title | `$app:risify.breadcrumb_custom_title` | `single_line_text_field` | Products & Collections |
| Similar collections | `$app:risify.collection_menu` | `list.collection_reference` | Collections only |
| Similar collections custom image | `$app:risify.collection_menu_custom_image` | `file_reference` | Collections only |
| Similar collections custom title | `$app:risify.collection_menu_custom_title` | `single_line_text_field` | Collections only |
| Similar collections description | `$app:risify.collection_menu_description` | `rich_text_field` | Collections only |
| Similar products | `$app:risify.related_products` | `list.product_reference` | Products only |
| Similar products custom image | `$app:risify.related_products_custom_image` | `file_reference` | Products only |
| Similar products custom title | `$app:risify.related_products_custom_title` | `single_line_text_field` | Products only |
| Discover suggestions | `$app:risify.related_searches` | `json` | Collections & Products (same key on both owner types) |
| Discover custom title | `$app:risify.discover_custom_title` | `single_line_text_field` | Collections |

**API patterns:**
- **Risify API (direct):** AI suggestions (`suggestBreadcrumbPath`, `generateBulkRecommendations`, `similarCollections`), recommendation management, semantic sync
- **Shopify Admin API (via shopifyProxy):** Reading/writing metafields, listing products/collections, feature activation (metafield definition creation)

## Discover is the odd one (READ FIRST)

Breadcrumbs and both Similar variants take Shopify GIDs (see the Architecture table above for exact `type` values). Discover does **NOT** — it takes handle-based URLs (`/collections/<handle>` or `/products/<handle>`).

If you only have a GID for a collection or product, resolve its `handle` first — via `collectionByHandle` / `productByHandle`, or by fetching `handle` alongside `id` in your initial `collections`/`products` query — before constructing the Discover URL. Writing `"url": "gid://shopify/..."` into a Discover entry corrupts the metafield: the storefront block reads `search.url` directly into an `<a href>`, so a GID there breaks every link.

When a bulk job touches more than one of these features in the same conversation (e.g. a spreadsheet import), treat Discover as the non-conformer.

## Prerequisites: Feature Activation

Navigation features must be activated before use. Each feature (Breadcrumbs, Similar collections, Similar products, Discover) is activated independently by creating its metafield definitions in Shopify.

### Check if features are activated

Query Shopify for metafield definitions in the `$app:risify` namespace:

```graphql
# Via shopifyProxy
query { metafieldDefinitions(namespace: "$app:risify", ownerType: PRODUCT, first: 50) { nodes { id name namespace key } } }
```

If the breadcrumb/collection_menu/related_searches keys don't exist, the feature needs activation.

### Activate a feature

Create the metafield definitions. Example for Breadcrumbs on Products:

```graphql
# Via shopifyProxy
mutation metafieldDefinitionCreate($definition: MetafieldDefinitionInput!) {
  metafieldDefinitionCreate(definition: $definition) {
    createdDefinition { id name namespace key type { name } ownerType }
    userErrors { field message code }
  }
}
```

Variables for each breadcrumb metafield definition:
```json
{
  "definition": {
    "name": "Risify Breadcrumb",
    "namespace": "$app:risify",
    "key": "breadcrumb",
    "type": "list.collection_reference",
    "ownerType": "PRODUCT",
    "access": { "admin": "MERCHANT_READ_WRITE", "storefront": "PUBLIC_READ" }
  }
}
```

Repeat for all metafield definitions needed per feature (see table above). Each feature needs definitions for all its metafield keys on the appropriate owner types.

---

## Flow: Breadcrumbs

Breadcrumbs define the navigation path for products and collections (e.g., Home > Women > Dresses > Red Dress).

### View current breadcrumbs

List collections/products with their current breadcrumb assignments:

```graphql
# Via shopifyProxy — Collections
query { collections(first: 20) { nodes { id title handle breadcrumbs: metafield(key: "$app:risify.breadcrumb") { jsonValue } } pageInfo { hasNextPage endCursor } } }
```

`jsonValue` returns an array of collection GIDs that form the breadcrumb trail.

### Set breadcrumbs manually

The user selects an ordered list of collections as the breadcrumb path.

```graphql
# Via shopifyProxy
mutation { metafieldsSet(metafields: [{
  ownerId: "gid://shopify/Collection/123"
  namespace: "$app:risify"
  key: "breadcrumb"
  value: "[\"gid://shopify/Collection/parent1\", \"gid://shopify/Collection/parent2\"]"
  type: "list.collection_reference"
}]) { metafields { id value } userErrors { field message } } }
```

Optional custom title:
```json
{
  "ownerId": "gid://shopify/Collection/123",
  "namespace": "$app:risify",
  "key": "breadcrumb_custom_title",
  "value": "Custom Display Name",
  "type": "single_line_text_field"
}
```

### AI breadcrumb suggestion (single collection)

```graphql
# Direct Risify mutation
mutation { suggestBreadcrumbPath(collectionId: "gid://shopify/Collection/123") { id title score } }
```

Returns ordered `BreadcrumbNode` items — a suggested path from root to the collection.

### Bulk AI breadcrumb generation

```graphql
# Direct Risify mutation
mutation {
  generateBulkRecommendations(
    collectionIds: ["gid://shopify/Collection/1", "gid://shopify/Collection/2"]
    types: [BREADCRUMBS]
  ) {
    results { collectionId breadcrumbs { id title handle score productCount } }
    errors { collectionId message }
    totalProcessed
    totalCreditsUsed
  }
}
```

### Remove breadcrumbs

Set the metafield value to an empty array:
```json
{ "ownerId": "gid://shopify/Collection/123", "namespace": "$app:risify", "key": "breadcrumb", "value": "[]", "type": "list.collection_reference" }
```

---

## Flow: Similar (collections + products)

"Similar" is the user-facing label. The metafield key depends on owner type:
- **Similar collections** → metafield key `collection_menu` (legacy name; UI label is "Similar")
- **Similar products** → metafield key `related_products`

When the user says "similar" without specifying, ask: "On your products or collections?" — these are different metafields with different recommendation types.

### View current Similar collections

```graphql
# Via shopifyProxy
query { collections(first: 20) { nodes { id title handle collectionMenus: metafield(key: "$app:risify.collection_menu") { jsonValue } } pageInfo { hasNextPage endCursor } } }
```

### Set Similar collections manually

```graphql
# Via shopifyProxy
mutation { metafieldsSet(metafields: [{
  ownerId: "gid://shopify/Collection/123"
  namespace: "$app:risify"
  key: "collection_menu"
  value: "[\"gid://shopify/Collection/sub1\", \"gid://shopify/Collection/sub2\"]"
  type: "list.collection_reference"
}]) { metafields { id value } userErrors { field message } } }
```

Optional custom fields (add to same metafieldsSet call):
```json
[
  { "ownerId": "...", "namespace": "$app:risify", "key": "collection_menu_custom_title", "value": "Shop by Category", "type": "single_line_text_field" },
  { "ownerId": "...", "namespace": "$app:risify", "key": "collection_menu_custom_image", "value": "gid://shopify/MediaImage/123", "type": "file_reference" },
  { "ownerId": "...", "namespace": "$app:risify", "key": "collection_menu_description", "value": "{\"type\":\"root\",\"children\":[...]}", "type": "rich_text_field" }
]
```

### AI Similar collections suggestions

```graphql
# Direct Risify query
query { similarCollections(collectionId: "gid://shopify/Collection/123", limit: 10, threshold: 0.75) { id title handle score } }
```

Or bulk generate:
```graphql
# Direct Risify mutation
mutation {
  generateBulkRecommendations(
    collectionIds: ["gid://shopify/Collection/1"]
    types: [COLLECTION_MENU]
  ) {
    results { collectionId collectionMenu { id title handle score productCount } }
    errors { collectionId message }
    totalProcessed
    totalCreditsUsed
  }
}
```

> Note on the enum name: `COLLECTION_MENU` is the GraphQL enum value (legacy). The user-facing label is "Similar collections". Never expose the enum name to the user.

### Similar products

Product-side "Similar" feature. Different metafield key — `related_products`, type `list.product_reference`.

**View current Similar products:**

```graphql
# Via shopifyProxy
query {
  product(id: "gid://shopify/Product/123") {
    id title handle
    relatedProducts: metafield(key: "$app:risify.related_products") { jsonValue }
    relatedProductsCustomTitle: metafield(key: "$app:risify.related_products_custom_title") { value }
  }
}
```

`jsonValue` is a JSON array of product GIDs: `["gid://shopify/Product/123", "gid://shopify/Product/456"]`.

**Set Similar products manually:**

```graphql
# Via shopifyProxy
mutation { metafieldsSet(metafields: [{
  ownerId: "gid://shopify/Product/123"
  namespace: "$app:risify"
  key: "related_products"
  value: "[\"gid://shopify/Product/abc\", \"gid://shopify/Product/def\"]"
  type: "list.product_reference"
}]) { metafields { id value } userErrors { field message } } }
```

Optional custom title (`related_products_custom_title`, `single_line_text_field`) — add to same `metafieldsSet` call.

**AI suggestions for Similar products:** None available. The schema has no `similarProducts` query (only `similarCollections` exists at present), and `generateBulkRecommendations` is hard-coded to `collectionIds: [ID!]!` with enum values `BREADCRUMBS`, `COLLECTION_MENU`, `RELATED_SEARCH` — all collection-side. Selection MUST be manual: `metafieldsSet` with hand-picked product GIDs. Do not promise the user AI bulk-generation for Similar products. If/when a product-side equivalent ships, document it here.

---

## Flow: Discover

Discover suggestions (legacy name "Related Searches") show relevant search terms on collection and product pages — e.g. "You might also like: summer dresses, floral prints". Stored in the `$app:risify.related_searches` metafield (`type: json`) — **same key on both Collection and Product owner types** (confirmed by `featureActivationConfig.ts`). Old name "Related Searches" — never use it with the user.

### Canonical entry shape

A valid related-search entry MUST have exactly these two fields:

```ts
{
  title: string,   // 1-80 chars, the visible label
  url: string      // matches ^/(collections|products)/[a-z0-9-]+$
}
```

The metafield value is a JSON array of these objects. Anything else is legacy or corrupt — never trust `jsonValue` blindly. Always run the audit flow below before writing.

> _**Last verified:** 2026-05-06 against `risifyv2_remix@ad330c8` (`app/features/risify/constants/featureActivationConfig.ts:222-263`, `pages/navigation/components/modals/BulkRelatedSearchEditModal.tsx`) and `risify-mcp-main@75876e9` (`schema.graphql` `RecommendationType:944-947`). Re-check this section when the in-app "Recover" flow ships, when the metafield definition changes, or when `featureActivationConfig.ts` is updated — the canonical shape and legacy-shape table here are derived from those sources._

### Recognized legacy / invalid shapes

Older stores may have any of these in `$app:risify.related_searches`:

| Symptom | Likely source | Action |
|---|---|---|
| Keys are `{name, link}`, `{label, slug}`, `{q, href}` | Pre-rename schema | FIXABLE — remap to `{title, url}` |
| Plain string entries (`["bestsellers", ...]`) | Earliest format | FIXABLE — wrap as `{title: humanize(handle), url: "/collections/<handle>"}`, confirm titles with user |
| Locale-prefixed url (`/en/collections/foo`, `/fr/...`) | Multi-language migration | FIXABLE — strip leading `/<lang>/` |
| Absolute url (`https://shop.com/collections/foo`) | Pasted by user or old AI flow | FIXABLE — strip origin |
| Missing `url` or `title`, empty handle after parse | Corruption | DROP — report to user |
| `jsonValue` is null but `value` is non-empty | Metafield definition `type` drift (e.g. `single_line_text_field`) | STOP — do NOT write; report definition mismatch |
| Non-array `jsonValue` (single object instead of array) | Buggy old write | FIXABLE — wrap in array |
| Entry handle resolves to neither a collection nor a product | Item deleted / renamed in Shopify | DROP — report broken link to user |

### View current Discover suggestions (always read `type`, `value`, AND `jsonValue`)

```graphql
# Via shopifyProxy
query {
  collection(id: "gid://shopify/Collection/123") {
    id title handle
    relatedSearches: metafield(key: "$app:risify.related_searches") {
      type value jsonValue
    }
  }
}
```

- If `type` is not `"json"` → metafield definition mismatch. Report to user, do not write.
- If `jsonValue` is null but `value` is non-empty → same issue. Report; do not write.
- If `jsonValue` is a single object → wrap in an array before classifying.

### Audit & repair existing entries (run before any write)

When the user asks to view, edit, or regenerate Discover suggestions, ALWAYS run this flow:

1. **Read** `type`, `value`, `jsonValue` (query above).
2. **Classify** each entry as VALID / FIXABLE / DROP / STOP using the table above.
3. **Normalize** FIXABLE entries:
   - Strip leading `/<lang>/` from url (regex: `^/[a-z]{2}/` → `/`)
   - Strip absolute origin from url (regex: `^https?://[^/]+` → ``)
   - Lowercase the handle segment
   - Map alternate key names to `{title, url}`
4. **Resolve** every handle to a real Shopify GID:

```graphql
# Via shopifyProxy
query ($h: String!) {
  collectionByHandle(handle: $h) { id title }
  productByHandle(handle: $h)    { id title }
}
```
   Drop entries where neither resolves.
5. **Report** counts to the user before writing:
   > "This collection has {N} discover suggestions. {V} are valid, {F} need repair, {D} will be dropped ({reasons}). Apply repairs?"
6. **Write** only on confirmation, using the canonical `{title, url}` shape.

See `references/navigation-operations.md` → "Audit Discover suggestions" and "Repair Discover suggestions" for full GraphQL.

### Set Discover suggestions manually

After audit + user confirmation:

```graphql
# Via shopifyProxy
mutation { metafieldsSet(metafields: [{
  ownerId: "gid://shopify/Collection/123"
  namespace: "$app:risify"
  key: "related_searches"
  value: "[{\"title\":\"Summer Dresses\",\"url\":\"/collections/summer-dresses\"},{\"title\":\"Floral Prints\",\"url\":\"/collections/floral\"}]"
  type: "json"
}]) { metafields { id value } userErrors { field message } } }
```

**Always** write the canonical `{title, url}` shape. If the existing payload had extra keys (description, image, custom title, etc.), drop them — the storefront and Risify dashboard only consume `title` and `url`. Future shape upgrades happen through the in-app Recover flow, not the AI.

### AI Discover suggestions

```graphql
# Direct Risify query
query { similarCollections(collectionId: "gid://shopify/Collection/123", limit: 10, threshold: 0.75) { id title handle score } }
```

Convert results to canonical Discover entry shape: `{ title: collection.title, url: "/collections/" + collection.handle }`

Or bulk generate:
```graphql
# Direct Risify mutation
mutation {
  generateBulkRecommendations(
    collectionIds: ["gid://shopify/Collection/1"]
    types: [RELATED_SEARCH]
  ) {
    results { collectionId relatedSearch { id title handle score productCount } }
    errors { collectionId message }
    totalProcessed
    totalCreditsUsed
  }
}
```

> AI-generated suggestions are already in canonical shape (`{title: collection.title, url: "/collections/" + collection.handle}`). No audit step needed for fresh writes — only when modifying an existing metafield that may have legacy data.

---

## Recommendation Management (UI: "AI Recommendations" tab; review modal: "Review & Save Recommendations")

After generating recommendations via `generateBulkRecommendations`, they are saved as `SavedRecommendation` objects that can be reviewed in the "AI Recommendations" tab.

### View recommendations for a collection

```graphql
# Direct Risify query
query { recommendationsByCollection(collectionId: "gid://shopify/Collection/123") { id collectionId collectionTitle recommendationType suggestedItems { id title handle score productCount } status createdAt } }
```

### View recommendation stats

```graphql
# Direct Risify query
query { recommendationStats { total pending accepted dismissed } }
```

### Accept/Dismiss a recommendation

```graphql
# Direct Risify mutation
mutation { updateRecommendationStatus(recommendationId: "rec-id", status: ACCEPTED) { id status } }
```

Status values: `PENDING`, `ACCEPTED`, `DISMISSED`

### Edit a recommendation

```graphql
# Direct Risify mutation
mutation { editRecommendation(recommendationId: "rec-id", suggestedItems: [
  { id: "gid://shopify/Collection/1", title: "Collection 1", handle: "collection-1", score: 0.95, productCount: 42 }
]) { id suggestedItems { id title handle score } } }
```

### View semantic tree (all recommendations overview)

```graphql
# Direct Risify query
query { semanticTree { clusters { id label coherence collections { id title handle productCount breadcrumbs { id title handle score } menu { id title handle score } related { id title handle score } } } unclustered { id title handle productCount breadcrumbs { id title handle score } menu { id title handle score } related { id title handle score } } totalCount } }
```

---

## Semantic Sync

Before AI recommendations work, collections must be synced (embedded) for semantic analysis.

### Check sync status

```graphql
# Direct Risify query
query { semanticSyncStatus { isSyncing status lastSyncedAt totalCount syncedCount failedCount } }
```

### Preview sync cost

```graphql
# Direct Risify query
query { semanticSyncPreview { totalCollections alreadySyncedCount toBeSyncedCount collectionsPerCredit estimatedCredits availableCredits hasUnlimitedCredits insufficientCredit } }
```

### Trigger sync

```graphql
# Direct Risify mutation
mutation { triggerEmbeddingSync }
```

This uses AI credits. Check `semanticSyncPreview` first to show the user the cost.

---

## Error Handling

| Situation | Response |
|-----------|----------|
| Feature not activated | Guide user to activate it. Create the metafield definitions via shopifyProxy |
| No semantic sync | AI suggestions won't work. Trigger `triggerEmbeddingSync` first |
| Insufficient credits for sync | Tell user. Direct to plan upgrade or credit management |
| generateBulkRecommendations errors | Check individual `errors` array — some collections may fail while others succeed |
| metafieldsSet fails | Check ownerId is valid, metafield definition exists |
| Legacy / unrecognized entry shape in related_searches | Run the Audit & repair flow in "Flow: Discover" — never overwrite blindly. Confirm dropped entries with the user first |
| Metafield definition `type` drift (jsonValue null while value non-empty) | Report the mismatch to the user. Do not write. They need to fix the metafield definition first |

## Constants

| UI label | Metafield key |
|---|---|
| Breadcrumbs | `breadcrumb` |
| Breadcrumbs custom title | `breadcrumb_custom_title` |
| Similar collections | `collection_menu` |
| Similar collections custom image | `collection_menu_custom_image` |
| Similar collections custom title | `collection_menu_custom_title` |
| Similar collections description | `collection_menu_description` |
| Similar products | `related_products` |
| Similar products custom image | `related_products_custom_image` |
| Similar products custom title | `related_products_custom_title` |
| Discover suggestions | `related_searches` |
| Discover custom title | `discover_custom_title` |

| Other | Value |
|---|---|
| Metafield namespace | `$app:risify` |
| Recommendation types (GraphQL enum, never user-facing) | `BREADCRUMBS`, `COLLECTION_MENU`, `RELATED_SEARCH` |
| Recommendation statuses | `PENDING`, `ACCEPTED`, `DISMISSED` |
| Max metafields per batch | 25 |
