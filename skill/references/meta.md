# Flow: Meta Tags Generation

Generate AI-powered SEO meta titles and descriptions for products and collections.

## Step-by-Step Flow

### Step 1: Check AI Credits

```graphql
query { aiCreditInfo { limit usage resetAt } }
```

If no credits remain, tell user and stop.

### Step 2: Identify Target Resources

Ask user which products or collections need meta tags.

**Products:**
```graphql
{ shopifyProductsConnection(args: { first: 20 }) { nodes { id title handle } pageInfo { hasNextPage endCursor } } }
```

**Collections:**
```graphql
{ shopifyCollectionsConnection(args: { first: 20 }) { nodes { id title handle productsCount } pageInfo { hasNextPage endCursor } } }
```

Collect selected GIDs.

### Step 3: Generate Meta Tags

**Single resource:**
```graphql
mutation { generateAIMeta(input: { resourceGID: "gid://shopify/Product/123" target: [SEO_TITLE, SEO_DESCRIPTION] tone: "professional" language: "en" }) { resourceGID seoTitle seoDescription creditsUsed } }
```

**Multiple resources (bulk):**
```graphql
mutation { bulkGenerateAIMeta(input: { resourceGIDs: ["gid://shopify/Product/123", "gid://shopify/Product/456"] target: [SEO_TITLE, SEO_DESCRIPTION] tone: "professional" language: "en" }) { results { resourceGID seoTitle seoDescription } errors { resourceGID message } totalCreditsUsed } }
```

| Param | Required | Values |
|-------|----------|--------|
| `resourceGID(s)` | yes | Shopify GIDs |
| `target` | yes | `SEO_TITLE`, `SEO_DESCRIPTION`, or both |
| `tone` | no | "professional", "friendly", "casual", "formal", "persuasive" |
| `language` | no | ISO code: "en", "fr", "de", etc. |

### Step 4: Review with User

Present generated meta tags for review:

```text
**{resource title}**
GID: {resourceGID}

SEO Title ({charCount} chars):
  Current: {currentTitle or "none"}
  → Generated: {seoTitle}

SEO Description ({charCount} chars):
  Current: {currentDescription or "none"}
  → Generated: {seoDescription}

Apply? (Yes / Edit / Skip)
```

**Guidelines:** SEO title should be under 60 characters. Description under 160 characters.

### Step 5: Apply Approved Meta Tags

To apply approved meta tags, update the resource via shopifyProxy:

**For products:**
```graphql
{ shopifyProxy(query: "mutation ($input: ProductInput!) { productUpdate(input: $input) { product { id title } userErrors { field message } } }" variables: { "input": { "id": "gid://shopify/Product/123", "seo": { "title": "Generated SEO Title", "description": "Generated SEO description" } } }) { data errors } }
```

**For collections:**
```graphql
{ shopifyProxy(query: "mutation ($input: CollectionInput!) { collectionUpdate(input: $input) { collection { id title } userErrors { field message } } }" variables: { "input": { "id": "gid://shopify/Collection/456", "seo": { "title": "Generated SEO Title", "description": "Generated SEO description" } } }) { data errors } }
```

### Step 6: Confirm

Report: "{N} meta tags applied to {M} resources."

## Error Handling

| Situation | Response |
|-----------|----------|
| No AI credits | Tell user. Suggest plan upgrade or wait for reset |
| Bulk generation partial failures | List successful resources, report failed ones with reasons |
| shopifyProxy update fails | Check userErrors for specific field issues |
