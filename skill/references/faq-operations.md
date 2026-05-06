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

## Bulk FAQ Mutations (Direct Risify API)

These mutations handle FAQ creation and assignment server-side — no `shopifyProxy` needed.

### Create and Assign FAQs (recommended)

Creates FAQ metaobjects AND assigns them to resources in **one call**. The backend handles merging with existing FAQ assignments automatically.

```graphql
mutation($input: BulkCreateAndAssignFaqsInput!) {
  bulkCreateAndAssignFaqs(input: $input) {
    created {
      results { index success metaobjectId handle error }
      successCount
      failureCount
    }
    assigned {
      results { resourceGID success finalFaqMetaobjectGIDs error }
      successCount
      failureCount
    }
    assignmentError
    createdMetaobjectGIDs
  }
}
```

Variables:
```json
{
  "input": {
    "items": [
      { "question": "What is your return policy?", "answer": "We offer 30-day returns on all products." },
      { "question": "Do you ship internationally?", "answer": "Yes, we ship to 50+ countries." }
    ],
    "resourceGIDs": ["gid://shopify/Product/123", "gid://shopify/Collection/456"]
  }
}
```

- Max 250 items per call, max 250 resources per call
- `created.successCount` / `failureCount` — how many metaobjects were created
- `assigned.successCount` / `failureCount` — how many resources were updated
- `createdMetaobjectGIDs` — GIDs of successfully created FAQ metaobjects

### Create FAQs Only (without assigning)

Creates FAQ metaobjects without assigning them to any resource. Useful for imports where assignment is done separately.

```graphql
mutation($input: BulkCreateFaqMetaobjectsInput!) {
  bulkCreateFaqMetaobjects(input: $input) {
    results { index success metaobjectId handle error }
    successCount
    failureCount
  }
}
```

Variables:
```json
{
  "input": {
    "items": [
      { "question": "What is your return policy?", "answer": "We offer 30-day returns." }
    ]
  }
}
```

### Assign Existing FAQs to Resources

Assigns already-created FAQ metaobject GIDs to resources. Merges with existing assignments — never overwrites.

```graphql
mutation($input: BulkAssignFaqsToResourcesInput!) {
  bulkAssignFaqsToResources(input: $input) {
    results { resourceGID success finalFaqMetaobjectGIDs error }
    successCount
    failureCount
  }
}
```

Variables:
```json
{
  "input": {
    "resourceGIDs": ["gid://shopify/Product/123"],
    "faqMetaobjectGIDs": ["gid://shopify/Metaobject/111", "gid://shopify/Metaobject/222"]
  }
}
```

---

## Shopify Admin API (via shopifyProxy)

These operations are wrapped in `shopifyProxy`. Only needed for update, delete, and listing — creation/assignment uses the bulk mutations above.

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
