# FAQ Import GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool. Shopify Admin API calls are wrapped in `shopifyProxy`.

---

## Risify API (Direct)

### List Collections
```graphql
{
  shopifyCollectionsConnection(args: {
    first: 250
    after: null
    query: null
    sortKey: TITLE
    reverse: false
  }) {
    nodes {
      id
      title
      handle
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

Paginate with `after: "<endCursor>"` for stores with >250 collections.

### List Products
```graphql
{
  shopifyProductsConnection(args: {
    first: 250
    after: null
    query: null
    sortKey: TITLE
    reverse: false
  }) {
    nodes {
      id
      title
      handle
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

---

## Shopify Admin API (via shopifyProxy)

All Shopify operations are wrapped in a `shopifyProxy` query. The `query` parameter contains the Shopify Admin GraphQL query/mutation as a string. The `variables` parameter is a JSON object.

### Discover Metaobject Type

Fetch all metaobject definitions to find the store-specific `risify_faq` type prefix.

```graphql
{
  shopifyProxy(
    query: "{ metaobjectDefinitions(first: 50) { edges { node { name type } } } }"
  ) {
    data
    errors
  }
}
```

Response path: `data.metaobjectDefinitions.edges[].node`

Find the entry whose `type` ends with `risify_faq` (not `risify_faq_tag`). Extract the full type (e.g. `app--234821386241--risify_faq`) and namespace prefix (e.g. `app--234821386241--risify`).

### Batch Create FAQ Metaobjects (Aliased)

Use aliased mutations to create up to 25 FAQ metaobjects per call. Replace `{TYPE}` with the discovered metaobject type.

```graphql
{
  shopifyProxy(
    query: "mutation { faq1: metaobjectCreate(metaobject: {type: \"{TYPE}\", fields: [{key: \"question\", value: \"Q1 text\"}, {key: \"answer\", value: \"A1 text\"}, {key: \"tags\", value: \"[]\"}]}) { metaobject { id } userErrors { field message code } } faq2: metaobjectCreate(metaobject: {type: \"{TYPE}\", fields: [{key: \"question\", value: \"Q2 text\"}, {key: \"answer\", value: \"A2 text\"}, {key: \"tags\", value: \"[]\"}]}) { metaobject { id } userErrors { field message code } } }"
  ) {
    data
    errors
  }
}
```

Response path: `data.faq1.metaobject.id`, `data.faq2.metaobject.id`, etc.

**Batching:** Max 25 aliases per call. Name sequentially: `faq1` through `faq25`.

### Create Single FAQ Metaobject (with variables)

```graphql
{
  shopifyProxy(
    query: "mutation metaobjectCreate($metaobject: MetaobjectCreateInput!) { metaobjectCreate(metaobject: $metaobject) { metaobject { id handle type displayName updatedAt fields { key value } } userErrors { field message code } } }"
    variables: {
      "metaobject": {
        "type": "$app:risify_faq",
        "fields": [
          { "key": "question", "value": "What is your return policy?" },
          { "key": "answer", "value": "We offer 30-day returns on all products." },
          { "key": "tags", "value": "[]" }
        ]
      }
    }
  ) {
    data
    errors
  }
}
```

Response path: `data.metaobjectCreate.metaobject.id`

### Read Existing FAQ Assignments on a Collection

```graphql
{
  shopifyProxy(
    query: "query ($id: ID!, $key: String!) { collection(id: $id) { id metafield(key: $key) { id value jsonValue } } }"
    variables: {
      "id": "gid://shopify/Collection/456",
      "key": "$app:risify.faq"
    }
  ) {
    data
    errors
  }
}
```

Response path: `data.collection.metafield.jsonValue` → array of metaobject GIDs

### Read Existing FAQ Assignments on a Product

```graphql
{
  shopifyProxy(
    query: "query ($id: ID!, $key: String!) { product(id: $id) { id metafield(key: $key) { id value jsonValue } } }"
    variables: {
      "id": "gid://shopify/Product/123",
      "key": "$app:risify.faq"
    }
  ) {
    data
    errors
  }
}
```

Response path: `data.product.metafield.jsonValue` → array of metaobject GIDs

### Assign FAQs to Resources (metafieldsSet)

```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Collection/456",
          "namespace": "$app:risify",
          "key": "faq",
          "value": "[\"gid://shopify/Metaobject/111\",\"gid://shopify/Metaobject/222\"]",
          "type": "list.metaobject_reference"
        }
      ]
    }
  ) {
    data
    errors
  }
}
```

**Important:** The `value` field must be a JSON-encoded string array of metaobject GIDs. Always use `variables` — never inline the value in the query string.

**Batch limit:** Max 25 metafields per call. Split into multiple calls if assigning to more than 25 resources.

### Get FAQ Metrics Count

```graphql
{
  shopifyProxy(
    query: "query ($type: String!) { metaobjectDefinitionByType(type: $type) { metaobjectsCount } }"
    variables: {
      "type": "$app:risify_faq"
    }
  ) {
    data
    errors
  }
}
```
