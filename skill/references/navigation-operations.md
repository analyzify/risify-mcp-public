# Navigation GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool. Risify API calls are direct. Shopify Admin API calls are wrapped in `shopifyProxy`.

---

## Risify API (Direct)

### Suggest Breadcrumb Path (single collection)
```graphql
mutation {
  suggestBreadcrumbPath(collectionId: "gid://shopify/Collection/123") {
    id
    title
    score
  }
}
```

### Generate Bulk Recommendations
```graphql
mutation {
  generateBulkRecommendations(
    collectionIds: ["gid://shopify/Collection/1", "gid://shopify/Collection/2"]
    types: [BREADCRUMBS, COLLECTION_MENU, RELATED_SEARCH]
  ) {
    results {
      collectionId
      breadcrumbs {
        id
        title
        handle
        score
        productCount
      }
      collectionMenu {
        id
        title
        handle
        score
        productCount
      }
      relatedSearch {
        id
        title
        handle
        score
        productCount
      }
    }
    errors {
      collectionId
      message
    }
    totalProcessed
    totalCreditsUsed
  }
}
```

Types enum: `BREADCRUMBS`, `COLLECTION_MENU`, `RELATED_SEARCH`

### Get Similar Collections
```graphql
query {
  similarCollections(
    collectionId: "gid://shopify/Collection/123"
    limit: 10
    threshold: 0.75
  ) {
    id
    title
    handle
    score
  }
}
```

### Get Recommendations by Collection
```graphql
query {
  recommendationsByCollection(collectionId: "gid://shopify/Collection/123") {
    id
    collectionId
    collectionTitle
    collectionHandle
    collectionImage
    recommendationType
    suggestedItems {
      id
      title
      handle
      score
      productCount
    }
    clusterId
    clusterLabel
    creditsUsed
    generationVersion
    status
    createdAt
    updatedAt
  }
}
```

### Get Recommendation Stats
```graphql
query {
  recommendationStats {
    total
    pending
    accepted
    dismissed
  }
}
```

### Update Recommendation Status
```graphql
mutation {
  updateRecommendationStatus(
    recommendationId: "rec-123"
    status: ACCEPTED
  ) {
    id
    status
    recommendationType
    suggestedItems {
      id
      title
      handle
      score
    }
  }
}
```

Status values: `PENDING`, `ACCEPTED`, `DISMISSED`

### Update Cluster Recommendation Status
```graphql
mutation {
  updateClusterRecommendationStatus(
    clusterId: 1
    status: ACCEPTED
  )
}
```

Returns count of updated recommendations.

### Edit Recommendation
```graphql
mutation {
  editRecommendation(
    recommendationId: "rec-123"
    suggestedItems: [
      {
        id: "gid://shopify/Collection/1"
        title: "Summer Collection"
        handle: "summer"
        score: 0.95
        productCount: 42
      },
      {
        id: "gid://shopify/Collection/2"
        title: "Beach Wear"
        handle: "beach-wear"
        score: 0.88
        productCount: 28
      }
    ]
  ) {
    id
    suggestedItems {
      id
      title
      handle
      score
      productCount
    }
    status
  }
}
```

### Get Semantic Tree (Full Overview)
```graphql
query {
  semanticTree(status: PENDING) {
    clusters {
      id
      label
      coherence
      depth
      parentClusterId
      collections {
        id
        title
        handle
        productCount
        breadcrumbs { id title handle score }
        menu { id title handle score }
        related { id title handle score }
      }
    }
    unclustered {
      id
      title
      handle
      productCount
      breadcrumbs { id title handle score }
      menu { id title handle score }
      related { id title handle score }
    }
    totalCount
  }
}
```

Optional `status` filter: `PENDING`, `ACCEPTED`, `DISMISSED` (omit for all).

### Get Semantic Sync Status
```graphql
query {
  semanticSyncStatus {
    isSyncing
    status
    lastSyncedAt
    totalCount
    syncedCount
    failedCount
  }
}
```

### Get Semantic Sync Preview
```graphql
query {
  semanticSyncPreview {
    totalCollections
    alreadySyncedCount
    toBeSyncedCount
    collectionsPerCredit
    estimatedCredits
    availableCredits
    hasUnlimitedCredits
    insufficientCredit
  }
}
```

### Trigger Embedding Sync
```graphql
mutation {
  triggerEmbeddingSync
}
```

---

## Shopify Admin API (via shopifyProxy)

### List Collections with Navigation Data
```graphql
{
  shopifyProxy(
    query: "query ($first: Int, $after: String) { collections(first: $first, after: $after) { nodes { id title handle breadcrumbs: metafield(key: \"$app:risify.breadcrumb\") { key jsonValue } collectionMenus: metafield(key: \"$app:risify.collection_menu\") { key jsonValue } relatedSearches: metafield(key: \"$app:risify.related_searches\") { key jsonValue } } pageInfo { hasNextPage endCursor } } }"
    variables: { "first": 20, "after": null }
  ) {
    data
    errors
  }
}
```

### List Products with Breadcrumbs
```graphql
{
  shopifyProxy(
    query: "query ($first: Int, $after: String) { products(first: $first, after: $after) { nodes { id title handle breadcrumbs: metafield(key: \"$app:risify.breadcrumb\") { key jsonValue } } pageInfo { hasNextPage endCursor } } }"
    variables: { "first": 20, "after": null }
  ) {
    data
    errors
  }
}
```

### Get Single Collection Navigation Data
```graphql
{
  shopifyProxy(
    query: "query ($id: ID!) { collection(id: $id) { id title handle breadcrumbs: metafield(key: \"$app:risify.breadcrumb\") { key jsonValue } collectionMenus: metafield(key: \"$app:risify.collection_menu\") { key jsonValue } relatedSearches: metafield(key: \"$app:risify.related_searches\") { key jsonValue } } }"
    variables: { "id": "gid://shopify/Collection/123" }
  ) {
    data
    errors
  }
}
```

### Set Breadcrumbs
```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "breadcrumb",
          "value": "[\"gid://shopify/Collection/parent1\",\"gid://shopify/Collection/parent2\"]",
          "type": "list.collection_reference"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

### Set Breadcrumb Custom Title
```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "breadcrumb_custom_title",
          "value": "Custom Breadcrumb Title",
          "type": "single_line_text_field"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

### Set Similar collections (legacy operation name: Collection Menu)
```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "collection_menu",
          "value": "[\"gid://shopify/Collection/sub1\",\"gid://shopify/Collection/sub2\"]",
          "type": "list.collection_reference"
        },
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "collection_menu_custom_title",
          "value": "Shop by Category",
          "type": "single_line_text_field"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

### Set Discover suggestions (legacy operation name: Related Searches)
```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "related_searches",
          "value": "[{\"title\":\"Summer Dresses\",\"url\":\"/collections/summer-dresses\"},{\"title\":\"Floral Prints\",\"url\":\"/collections/floral\"}]",
          "type": "json"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

### Set Similar products

Three metafields: the list (`related_products`, `list.product_reference`), optional custom image (`related_products_custom_image`, `file_reference`), and optional custom title (`related_products_custom_title`, `single_line_text_field`). All on Product ownerType.

```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Product/123",
          "namespace": "$app:risify",
          "key": "related_products",
          "value": "[\"gid://shopify/Product/abc\",\"gid://shopify/Product/def\"]",
          "type": "list.product_reference"
        },
        {
          "ownerId": "gid://shopify/Product/123",
          "namespace": "$app:risify",
          "key": "related_products_custom_image",
          "value": "gid://shopify/MediaImage/123",
          "type": "file_reference"
        },
        {
          "ownerId": "gid://shopify/Product/123",
          "namespace": "$app:risify",
          "key": "related_products_custom_title",
          "value": "You may also like",
          "type": "single_line_text_field"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

**View current Similar products:**

```graphql
{
  shopifyProxy(
    query: "query ($id: ID!) { product(id: $id) { id title handle relatedProducts: metafield(key: \"$app:risify.related_products\") { jsonValue } relatedProductsCustomImage: metafield(key: \"$app:risify.related_products_custom_image\") { value } relatedProductsCustomTitle: metafield(key: \"$app:risify.related_products_custom_title\") { value } } }"
    variables: { "id": "gid://shopify/Product/123" }
  ) {
    data
    errors
  }
}
```

**Note on AI suggestions:** None available for Similar products. The schema has no `similarProducts` query, and `generateBulkRecommendations` is hard-coded to `collectionIds: [ID!]!` with enum values `BREADCRUMBS / COLLECTION_MENU / RELATED_SEARCH` — all collection-side. Selection must be manual.

### Audit Discover suggestions (legacy operation name: Audit Related Searches)

Read `type`, `value`, AND `jsonValue` together so the AI can detect definition drift and parse fallbacks:

```graphql
{
  shopifyProxy(
    query: "query ($id: ID!) { collection(id: $id) { id title handle metafield(key: \"$app:risify.related_searches\") { type value jsonValue } } }"
    variables: { "id": "gid://shopify/Collection/123" }
  ) {
    data
    errors
  }
}
```

**Interpret results:**
- `type !== "json"` → definition drift. Stop. Report to user.
- `jsonValue === null && value !== null` → same issue. Stop.
- `jsonValue` is an object (not array) → wrap in array, classify the single entry.
- `jsonValue` is an array → classify each entry (see classification table in `navigation.md`).

### Repair Discover suggestions (legacy operation name: Repair Related Searches)

Full audit → resolve → rewrite cycle. Run when the user asks to view/edit/regenerate Discover suggestions and audit finds FIXABLE or DROP entries.

**Step 1 — Audit** (query above).

**Step 2 — Normalize FIXABLE entries:**
- Strip leading `/<lang>/` from url (`^/[a-z]{2}/` → `/`)
- Strip absolute origin (`^https?://[^/]+` → ``)
- Map alternate key names: `name`→`title`, `link|href|slug`→`url`
- Wrap plain-string entries: `"bestsellers"` → `{title: "Bestsellers", url: "/collections/bestsellers"}`

**Step 3 — Resolve every handle:**

```graphql
{
  shopifyProxy(
    query: "query ($h: String!) { collectionByHandle(handle: $h) { id title } productByHandle(handle: $h) { id title } }"
    variables: { "h": "summer-dresses" }
  ) {
    data
    errors
  }
}
```

Drop entries where both resolve to null.

**Step 4 — Confirm with user:**
> "{V} valid, {F} repaired, {D} dropped ({reasons}). Apply?"

**Step 5 — Write canonical payload:**

```json
[
  { "title": "Summer Dresses", "url": "/collections/summer-dresses" },
  { "title": "Floral Prints",  "url": "/collections/floral" }
]
```

via the "Set Discover suggestions" mutation above. Use `type: "json"` and namespace `$app:risify`. Never include extra keys — strip `description`, `image`, `customImageGid`, etc., from any legacy entries.

### Remove Navigation Data (Clear)
```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/123",
          "namespace": "$app:risify",
          "key": "breadcrumb",
          "value": "[]",
          "type": "list.collection_reference"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

### Create Metafield Definition (Feature Activation)
```graphql
{
  shopifyProxy(
    query: "mutation metafieldDefinitionCreate($definition: MetafieldDefinitionInput!) { metafieldDefinitionCreate(definition: $definition) { createdDefinition { id name namespace key type { name } ownerType description } userErrors { field message code } } }"
    variables: {
      "definition": {
        "name": "Risify Breadcrumb",
        "namespace": "$app:risify",
        "key": "breadcrumb",
        "type": "list.collection_reference",
        "ownerType": "PRODUCT",
        "description": "Breadcrumb navigation configuration",
        "access": {
          "admin": "MERCHANT_READ_WRITE",
          "storefront": "PUBLIC_READ"
        }
      }
    }
  ) {
    data
    errors
  }
}
```

### Check Metafield Definitions (Feature Status)
```graphql
{
  shopifyProxy(
    query: "query ($namespace: String!, $ownerType: MetafieldOwnerType!) { metafieldDefinitions(namespace: $namespace, ownerType: $ownerType, first: 50) { nodes { id name namespace key } } }"
    variables: {
      "namespace": "$app:risify",
      "ownerType": "PRODUCT"
    }
  ) {
    data
    errors
  }
}
```

---

## Type Reference

### BreadcrumbNode
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Collection GID |
| `title` | String! | Collection title |
| `score` | Float! | AI confidence score |

### RecommendationItem
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Collection GID |
| `title` | String! | Collection title |
| `handle` | String! | Collection handle |
| `score` | Float! | AI relevance score |
| `productCount` | Int! | Number of products |

### SavedRecommendation
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Recommendation ID |
| `collectionId` | ID! | Target collection |
| `recommendationType` | RecommendationType! | BREADCRUMBS, COLLECTION_MENU, RELATED_SEARCH |
| `suggestedItems` | [RecommendationItem!]! | Suggested collections |
| `status` | RecommendationStatus! | PENDING, ACCEPTED, DISMISSED |
| `creditsUsed` | Int! | AI credits consumed |

### SemanticMatch
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Collection GID |
| `title` | String! | Collection title |
| `handle` | String! | Collection handle |
| `score` | Float! | Similarity score (0-1) |

### SyncStatus
| Field | Type | Description |
|-------|------|-------------|
| `isSyncing` | Boolean! | Whether sync is in progress |
| `status` | String! | Sync status |
| `lastSyncedAt` | Time | Last sync timestamp |
| `totalCount` | Int! | Total collections |
| `syncedCount` | Int! | Successfully synced |
| `failedCount` | Int! | Failed to sync |
