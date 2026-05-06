# Flow: FAQ Generation & Assignment

Generate AI-powered FAQs and save them to Shopify as metaobjects linked to products, collections, or pages.

## Architecture

FAQs are **Shopify Metaobjects** (type `$app:risify_faq`) with fields `question`, `answer`, `tags`. They are linked to resources via **metafields** (namespace `$app:risify`, key `faq`, type `list.metaobject_reference`).

- Generation uses the **Risify API** directly (`generateAIFAQ`)
- Saving/assigning uses the **Risify API** directly (`bulkCreateAndAssignFaqs`) — one call creates metaobjects AND assigns them to resources

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

Present each generated FAQ for approval. ALWAYS use this exact template:

```
**FAQ #N**
Q: {question}
A: {answer}
→ Accept / Edit / Discard?
```

**Handling responses:**
- **Accept** → Add to the approved list for Step 5
- **Edit** → Ask user for revised Q&A, update the item, re-confirm, then add to approved list
- **Discard** → Skip this FAQ entirely

After all FAQs are reviewed, confirm the final list: "Saving {N} FAQs to {M} resources. Proceed?"
If no FAQs were accepted, stop and inform user.

### Step 5: Save and Assign FAQs

Use `bulkCreateAndAssignFaqs` to create all accepted FAQs and assign them to the selected resources in **one call**:

```graphql
mutation($input: BulkCreateAndAssignFaqsInput!) {
  bulkCreateAndAssignFaqs(input: $input) {
    created {
      results { index success metaobjectId error }
      successCount
      failureCount
    }
    assigned {
      results { resourceGID success finalFaqMetaobjectGIDs error }
      successCount
      failureCount
    }
    createdMetaobjectGIDs
    assignmentError
  }
}
```

Variables — put the accepted questions/answers in `items` and the resource GIDs from Step 2 in `resourceGIDs`:
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

This single call creates FAQ metaobjects, assigns them to all specified resources, and merges with any existing FAQ assignments. Max 250 items per call.

Check `created.successCount` and `assigned.successCount` in the response to confirm results.

**Note:** `assigned` may be null if all FAQ creations failed. Always check `created.failureCount` first — if all items failed, skip assignment reporting.

### Step 6: Confirm

Tell the user how many FAQs were created and which resources they were assigned to.

## Additional Workflows

### List Existing FAQs

Use the List Existing FAQs query from `faq-operations.md`. Present results as:

```text
Your FAQs ({count} total):

1. Q: {question}
   A: {answer}
   ID: {metaobject GID}

2. Q: {question}
   A: {answer}
   ID: {metaobject GID}

{pagination info if more pages}
```

### Update a FAQ

1. Find the FAQ — list FAQs and let user identify which one (by number or question text)
2. Ask what to change (question, answer, or both)
3. Use the Update FAQ Metaobject mutation from `faq-operations.md`
4. Confirm: "FAQ updated successfully."

### Delete a FAQ

1. Find the FAQ — list FAQs and let user identify which one
2. **Confirm before deleting:** "Delete FAQ: '{question}'? This cannot be undone."
3. Use the Delete FAQ Metaobject mutation from `faq-operations.md`
4. Confirm: "FAQ deleted."

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
| bulkCreateAndAssignFaqs fails | FAQ feature may not be activated. User must enable it in Risify first |
| Partial failures | Check `created.failureCount` and `assigned.failureCount` — some items may succeed while others fail |
| shopifyProxy errors (update/delete) | Check `errors` field. Common: access denied, rate limited |
