# Flow: Navigation Management

Manage Breadcrumbs, Collection Menus, and Related Searches for Shopify products and collections. Includes AI-powered suggestions and bulk generation.

## Architecture

Navigation data is stored as **Shopify metafields** on products and collections:

| Feature | Metafield Key | Type | Applies To |
|---------|--------------|------|------------|
| Breadcrumbs | `$app:risify.breadcrumb` | `list.collection_reference` | Products & Collections |
| Breadcrumb Custom Title | `$app:risify.breadcrumb_custom_title` | `single_line_text_field` | Products & Collections |
| Collection Menu | `$app:risify.collection_menu` | `list.collection_reference` | Collections only |
| Collection Menu Custom Image | `$app:risify.collection_menu_custom_image` | `file_reference` | Collections only |
| Collection Menu Custom Title | `$app:risify.collection_menu_custom_title` | `single_line_text_field` | Collections only |
| Collection Menu Description | `$app:risify.collection_menu_description` | `rich_text_field` | Collections only |
| Related Searches | `$app:risify.related_searches` | `json` | Collections only |

**API patterns:**
- **Risify API (direct):** AI suggestions (`suggestBreadcrumbPath`, `generateBulkRecommendations`, `similarCollections`), recommendation management, semantic sync
- **Shopify Admin API (via shopifyProxy):** Reading/writing metafields, listing products/collections, feature activation (metafield definition creation)

## Prerequisites: Feature Activation

Navigation features must be activated before use. Each feature (Breadcrumb, Collection Menu, Related Searches) is activated independently by creating its metafield definitions in Shopify.

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

## Flow: Collection Menu

Collection Menus show related/sub-collections within a collection page.

### View current collection menus

```graphql
# Via shopifyProxy
query { collections(first: 20) { nodes { id title handle collectionMenus: metafield(key: "$app:risify.collection_menu") { jsonValue } } pageInfo { hasNextPage endCursor } } }
```

### Set collection menu manually

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

### AI collection menu suggestions

Use similar collections to suggest menu items:

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

---

## Flow: Related Searches

Related Searches show relevant search terms on collection pages (e.g., "You might also like: summer dresses, floral prints").

### View current related searches

```graphql
# Via shopifyProxy
query { collections(first: 20) { nodes { id title handle relatedSearches: metafield(key: "$app:risify.related_searches") { jsonValue } } pageInfo { hasNextPage endCursor } } }
```

`jsonValue` returns a JSON array of `[{ "title": "Search Term", "url": "/collections/handle" }, ...]`

### Set related searches manually

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

### AI related search suggestions

```graphql
# Direct Risify query
query { similarCollections(collectionId: "gid://shopify/Collection/123", limit: 10, threshold: 0.75) { id title handle score } }
```

Convert results to related search format: `{ title: collection.title, url: "/collections/" + collection.handle }`

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

---

## Recommendation Management

After generating recommendations via `generateBulkRecommendations`, they are saved as `SavedRecommendation` objects that can be reviewed.

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

## Constants

| Key | Value |
|-----|-------|
| Breadcrumb metafield key | `breadcrumb` |
| Breadcrumb custom title key | `breadcrumb_custom_title` |
| Collection menu key | `collection_menu` |
| Collection menu custom image key | `collection_menu_custom_image` |
| Collection menu custom title key | `collection_menu_custom_title` |
| Collection menu description key | `collection_menu_description` |
| Related searches key | `related_searches` |
| Metafield namespace | `$app:risify` |
| Recommendation types | `BREADCRUMBS`, `COLLECTION_MENU`, `RELATED_SEARCH` |
| Recommendation statuses | `PENDING`, `ACCEPTED`, `DISMISSED` |
| Max metafields per batch | 25 |
