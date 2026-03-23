# GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool. Risify API calls are direct. Shopify Admin API calls are wrapped in `shopifyProxy`.

---

## Risify API (Direct)

### Check AI Credits
```graphql
query {
  aiCreditInfo {
    limit
    usage
    resetAt
  }
}
```

### List Products
```graphql
{
  shopifyProductsConnection(args: {
    first: 20
    after: null
    query: null
    sortKey: TITLE
    reverse: false
  }) {
    nodes {
      id
      title
      handle
      description
      imageUrl
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

### List Collections
```graphql
{
  shopifyCollectionsConnection(args: {
    first: 20
    after: null
    query: null
    sortKey: TITLE
    reverse: false
  }) {
    nodes {
      id
      title
      handle
      description
      productsCount
      imageUrl
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

### Generate FAQs
```graphql
mutation {
  generateAIFAQ(input: {
    resourceGIDs: ["gid://shopify/Product/123", "gid://shopify/Collection/456"]
    count: 3
    language: "en"
    tone: "professional"
  }) {
    faqs {
      question
      answer
    }
    creditsUsed
  }
}
```

### Get Product/Collection Counts (Overview)
```graphql
{
  shopifyProductsConnection(args: { first: 1 }) {
    pageInfo { totalCount }
  }
  shopifyCollectionsConnection(args: { first: 1 }) {
    pageInfo { totalCount }
  }
}
```

---

## Shopify Admin API (via shopifyProxy)

All Shopify operations are wrapped in a `shopifyProxy` query. The `query` parameter contains the Shopify Admin GraphQL query/mutation as a string. The `variables` parameter is a JSON object.

### Create FAQ Metaobject

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

### Update FAQ Metaobject

```graphql
{
  shopifyProxy(
    query: "mutation metaobjectUpdate($id: ID!, $metaobject: MetaobjectUpdateInput!) { metaobjectUpdate(id: $id, metaobject: $metaobject) { metaobject { id handle type displayName updatedAt fields { key value } } userErrors { field message code } } }"
    variables: {
      "id": "gid://shopify/Metaobject/123",
      "metaobject": {
        "fields": [
          { "key": "question", "value": "Updated question?" },
          { "key": "answer", "value": "Updated answer." }
        ]
      }
    }
  ) {
    data
    errors
  }
}
```

### Delete FAQ Metaobject

```graphql
{
  shopifyProxy(
    query: "mutation metaobjectDelete($id: ID!) { metaobjectDelete(id: $id) { deletedId userErrors { field message code } } }"
    variables: {
      "id": "gid://shopify/Metaobject/123"
    }
  ) {
    data
    errors
  }
}
```

### List Existing FAQs

```graphql
{
  shopifyProxy(
    query: "query ($type: String!, $first: Int, $after: String) { metaobjects(type: $type, first: $first, after: $after) { nodes { id handle fields { key value } } pageInfo { hasNextPage endCursor } } }"
    variables: {
      "type": "$app:risify_faq",
      "first": 20,
      "after": null
    }
  ) {
    data
    errors
  }
}
```

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

### Assign FAQs to Resources (metafieldsSet)

```graphql
{
  shopifyProxy(
    query: "mutation metafieldsSet($metafields: [MetafieldsSetInput!]!) { metafieldsSet(metafields: $metafields) { metafields { id value } userErrors { field message } } }"
    variables: {
      "metafields": [
        {
          "ownerId": "gid://shopify/Product/123",
          "namespace": "$app:risify",
          "key": "faq",
          "value": "[\"gid://shopify/Metaobject/111\",\"gid://shopify/Metaobject/222\"]",
          "type": "list.metaobject_reference"
        },
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

**Important:** The `value` field must be a JSON-encoded string array of metaobject GIDs. Always merge with existing assignments — never overwrite.

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
