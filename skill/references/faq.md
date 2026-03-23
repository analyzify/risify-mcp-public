# Flow: FAQ Generation & Assignment

Generate AI-powered FAQs and save them to Shopify as metaobjects linked to products, collections, or pages.

## Architecture

FAQs are **Shopify Metaobjects** (type `$app:risify_faq`) with fields `question`, `answer`, `tags`. They are linked to resources via **metafields** (namespace `$app:risify`, key `faq`, type `list.metaobject_reference`).

- Generation uses the **Risify API** directly (`generateAIFAQ`)
- Saving/assigning uses the **Shopify Admin API** via `shopifyProxy`

## Step-by-Step Flow

Follow these steps in order. Do not skip steps.

### Step 1: Check AI Credits

```graphql
query { aiCreditInfo { limit usage resetAt } }
```

- `limit = -1` → unlimited. `limit = 0` → disabled.
- Available = `limit - usage` (when limit > 0)
- If zero credits remain, tell the user and stop. Direct them to Risify app > Support > AI Credits.

### Step 2: Identify Target Resources

Ask the user which products and/or collections they want FAQs for.

**Products:**
```graphql
{ shopifyProductsConnection(args: { first: 20 }) { nodes { id title handle description imageUrl } pageInfo { hasNextPage endCursor } } }
```

**Collections:**
```graphql
{ shopifyCollectionsConnection(args: { first: 20 }) { nodes { id title handle description productsCount imageUrl } pageInfo { hasNextPage endCursor } } }
```

- Paginate with `after: "<endCursor>"`
- Filter with `query: "title:*keyword*"`
- Max 50 items per generation batch
- Collect selected GIDs (e.g., `gid://shopify/Product/123`)

### Step 3: Generate FAQs

```graphql
mutation { generateAIFAQ(input: { resourceGIDs: ["gid://shopify/Product/123"] count: 3 language: "en" tone: "professional" }) { faqs { question answer } creditsUsed } }
```

| Param | Required | Values |
|-------|----------|--------|
| `resourceGIDs` | yes | Array of Shopify GIDs |
| `count` | yes | 1–10 |
| `tone` | no | "professional", "friendly", "casual" |
| `language` | no | ISO code: "en", "fr", "de", etc. |

### Step 4: Review with User

Present each generated FAQ. The user may accept, edit, or discard.

ALWAYS use this exact template:

```
**FAQ #N**
Q: {question}
A: {answer}
→ Accept / Edit / Discard?
```

### Step 5: Save as Shopify Metaobjects

For each accepted FAQ, create a metaobject via shopifyProxy. See `faq-operations.md` for the exact query.

Create one metaobject per FAQ with:
- type: `$app:risify_faq`
- fields: `question`, `answer`, `tags` (tags defaults to `"[]"`)

Collect all created metaobject IDs from the response.

### Step 6: Assign to Resources

Link the new FAQ metaobjects to the selected products/collections by setting metafields.

For each resource:
1. Read its existing FAQ metafield to get current FAQ IDs
2. Merge new FAQ IDs with existing ones (deduplicate)
3. Write the updated list back via `metafieldsSet`

See `faq-operations.md` for exact queries. Batch limit: max 25 metafields per `metafieldsSet` call.

### Step 7: Confirm

Tell the user how many FAQs were created and which resources they were assigned to.

## Additional Operations

| Task | Method |
|------|--------|
| List existing FAQs | shopifyProxy → `metaobjects(type: "$app:risify_faq")` |
| Update a FAQ | shopifyProxy → `metaobjectUpdate` |
| Delete a FAQ | shopifyProxy → `metaobjectDelete` |
| View FAQ count | `shopifyProductsConnection` / `shopifyCollectionsConnection` with `pageInfo.totalCount` |

## Constants

| Key | Value |
|-----|-------|
| Metaobject type | `$app:risify_faq` |
| Metafield namespace | `$app:risify` |
| Metafield key | `faq` |
| Metafield key (query format) | `$app:risify.faq` |
| Metafield type | `list.metaobject_reference` |
| Max selection per batch | 50 |
| FAQ count range | 1–10 |

## Error Handling

| Situation | Response |
|-----------|----------|
| No AI credits | Tell user. Direct to Risify > Support > AI Credits |
| Invalid resource GIDs | Verify selections exist. Re-fetch if needed |
| metaobjectCreate fails | FAQ feature may not be activated. User must enable it in Risify first |
| metafieldsSet fails | Check ownerId validity and that metafield definition exists |
| shopifyProxy errors | Check `errors` field. Common: access denied, rate limited |
