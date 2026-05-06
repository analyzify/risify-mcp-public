# Meta Tags GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool.

---

## Risify API (Direct)

### Generate Meta Tags (Single Resource)
```graphql
mutation {
  generateAIMeta(input: {
    resourceGID: "gid://shopify/Product/123"
    target: [SEO_TITLE, SEO_DESCRIPTION]
    tone: "professional"
    language: "en"
  }) {
    resourceGID
    seoTitle
    seoDescription
    creditsUsed
  }
}
```

### Generate Meta Tags (Bulk)
```graphql
mutation {
  bulkGenerateAIMeta(input: {
    resourceGIDs: ["gid://shopify/Product/123", "gid://shopify/Product/456"]
    target: [SEO_TITLE, SEO_DESCRIPTION]
    tone: "professional"
    language: "en"
  }) {
    results {
      resourceGID
      seoTitle
      seoDescription
    }
    errors {
      resourceGID
      message
    }
    totalCreditsUsed
  }
}
```

Target enum: `SEO_TITLE`, `SEO_DESCRIPTION`

### Async Bulk Meta Generation (for large batches)

**Start:**
```graphql
mutation {
  startBulkMetaGeneration(input: {
    resourceGIDs: ["gid://shopify/Product/1", "gid://shopify/Product/2"]
    targets: [SEO_TITLE, SEO_DESCRIPTION]
    tone: "professional"
    language: "en"
  }) {
    taskId
    alreadyRunning
  }
}
```

**Poll progress:**
```graphql
query {
  generationTaskStatus(taskId: "<task-id>") {
    taskId
    status
    progress {
      totalCount
      completedCount
      failedCount
      percent
      phase
      phaseLabel
    }
  }
}
```

**Get results:**
```graphql
query {
  generationTaskResults(taskId: "<task-id>") {
    ... on MetaGenerationResults {
      items {
        resourceGID
        resourceType
        title
        seoTitle
        seoDescription
        currentSeoTitle
        currentSeoDescription
      }
    }
  }
}
```

---

## Shopify Admin API (via shopifyProxy)

### Apply Meta Tags to Product
```graphql
{
  shopifyProxy(
    query: "mutation ($input: ProductInput!) { productUpdate(input: $input) { product { id title } userErrors { field message } } }"
    variables: {
      "input": {
        "id": "gid://shopify/Product/123",
        "seo": {
          "title": "Optimized SEO Title",
          "description": "Optimized SEO description for better search visibility."
        }
      }
    }
  ) {
    data
    errors
  }
}
```

### Apply Meta Tags to Collection
```graphql
{
  shopifyProxy(
    query: "mutation ($input: CollectionInput!) { collectionUpdate(input: $input) { collection { id title } userErrors { field message } } }"
    variables: {
      "input": {
        "id": "gid://shopify/Collection/456",
        "seo": {
          "title": "Optimized Collection Title",
          "description": "Optimized collection description."
        }
      }
    }
  ) {
    data
    errors
  }
}
```
