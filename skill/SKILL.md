---
name: risify
description: >
  Complete skill for the Risify Shopify SEO app. Covers all Risify features and workflows.
  Trigger when the user wants to: generate FAQs, manage FAQs, import FAQs from CSV/Excel,
  bulk-add FAQs, upload FAQ files, view account info, check AI credits,
  manage subscription/billing/plans, add/edit/remove team contacts, view billing history,
  cancel subscription, upgrade plan, assign FAQs to products or collections,
  manage breadcrumbs, set up collection menus, configure related searches,
  generate AI navigation recommendations, activate navigation features, sync collections for AI,
  or any Risify-related task. Covers questions like: "generate FAQs for my products",
  "import FAQs", "upload FAQs from CSV", "bulk add FAQs", "add FAQs from file",
  "import questions and answers", "add these FAQs to my collections",
  "what plan am I on", "how many credits do I have", "add a team member",
  "show my billing history", "cancel my subscription", "list my FAQs",
  "set up breadcrumbs", "suggest breadcrumbs with AI", "add collection menu",
  "configure related searches", "generate navigation recommendations".
  All operations use the execute_graphql MCP tool.
---

# Risify MCP Skill

Complete workflow guide for the Risify Shopify SEO platform. All operations go through the `execute_graphql` MCP tool.

**Two API patterns:**
- **Risify API** — direct queries/mutations (e.g., `generateAIFAQ`, `aiCreditInfo`, `me`)
- **Shopify Admin API** — wrapped in `shopifyProxy(query: "...", variables: {...})` which proxies to Shopify through the Risify backend. No separate Shopify token needed.

## Available Flows

| Flow | Trigger | Reference |
|------|---------|-----------|
| FAQ Generation & Assignment | User wants to generate, create, list, update, delete, or assign FAQs | `references/faq.md` + `references/faq-operations.md` |
| Account Management | User asks about account, billing, plans, contacts, credits, subscription | `references/account.md` + `references/account-operations.md` |
| Navigation | User wants breadcrumbs, collection menus, related searches, AI navigation suggestions, feature activation | `references/navigation.md` + `references/navigation-operations.md` |
| FAQ Import | User wants to import, upload, or bulk-add FAQs from a CSV/Excel file | See FAQ Import section below + `references/faq-operations.md` |

## How to Use

1. Match the user's request to a flow above
2. Load the corresponding reference files for instructions and exact GraphQL operations
3. Follow the step-by-step flow in the reference file
4. Present results using the templates provided

## Quick Reference

### Common Queries (no reference file needed)

**Check AI Credits:**
```graphql
query { aiCreditInfo { limit usage resetAt } }
```

**Get Account Info:**
```graphql
query { me { id fullName email shopName shopUrl domain isAppSubscriptionPlanActive appSubscriptionCharge { name status subscriptionPeriodEnd } } }
```

**List Products:**
```graphql
{ shopifyProductsConnection(args: { first: 20 }) { nodes { id title handle } pageInfo { hasNextPage endCursor } } }
```

**List Collections:**
```graphql
{ shopifyCollectionsConnection(args: { first: 20 }) { nodes { id title handle productsCount } pageInfo { hasNextPage endCursor } } }
```

---

## Flow: FAQ Import from CSV/Excel

Import pre-written FAQ content from CSV/Excel files into a Shopify store by creating FAQ metaobjects and assigning them to collections, products, or pages — all through Risify's `shopifyProxy`.

**Trigger phrases:** "import FAQs", "upload FAQs", "CSV FAQs", "Excel FAQs", "bulk FAQs", "add FAQs from file", "import questions and answers", "add these FAQs to my collections", "attach FAQs to products", or when a user uploads a CSV/Excel file containing FAQ-like columns (Question, Answer, Collection).

### Prerequisites

- Risify MCP connected with `execute_graphql` tool available
- The store must have the Risify FAQ metaobject definition installed (type: `app--{APP_ID}--risify_faq`)
- User provides a CSV or Excel file with FAQ content

### Core workflow

Always follow this order:

1. **Parse the file** — identify columns, group FAQs by resource
2. **Discover the store's metaobject type** — fetch the exact `risify_faq` type prefix
3. **Fetch resources** — build a title→GID lookup map
4. **Match** — resolve file resource names to Shopify GIDs
5. **Create metaobjects** — batch-create FAQ metaobjects via shopifyProxy
6. **Assign to resources** — update each resource's `faq` metafield
7. **Report results** — show imported/skipped/failed counts

Never skip step 2. The app ID in the metaobject type varies per store.

### Step 1 — Parse the file

Accept CSV or Excel files. Look for columns that map to:

| Required | Column patterns to match |
|----------|--------------------------|
| Resource name | `Collection`, `Product`, `Page`, `Resource`, `Category` |
| Question | `Question`, `Q`, `FAQ Question` |
| Answer | `Answer`, `A`, `FAQ Answer`, `Response` |

| Optional | Column patterns |
|----------|----------------|
| Position/order | `Q#`, `Number`, `Position`, `Order` |
| Tags | `Tag`, `Tags`, `Category` |

If column mapping is ambiguous, ask the user to confirm before proceeding.

Group rows by resource name. Track the count per resource for the summary.

### Step 2 — Discover the metaobject type

The metaobject type includes the Shopify app ID which varies per installation. Fetch it dynamically:

```graphql
query {
  shopifyProxy(query: """
    {
      metaobjectDefinitions(first: 50) {
        edges {
          node { name type }
        }
      }
    }
  """) { data errors }
}
```

Find the definition whose `type` ends with `risify_faq` (not `risify_faq_tag`). Extract the full type string (e.g. `app--234821386241--risify_faq`) and the namespace prefix (e.g. `app--234821386241--risify`).

Store both — you'll need the type for `metaobjectCreate` and the namespace for `metafieldsSet`.

### Step 3 — Fetch resources for matching

Fetch all collections (or products) to build a title→GID map.

See `references/faq-operations.md` for the paginated query patterns (List Collections, List Products via Risify API). For stores with >250 collections, paginate with cursor.

### Step 4 — Match resource names

For each unique resource name in the file:

1. **Normalize** both the file name and Shopify titles: lowercase, trim, collapse whitespace
2. **Exact match first** — if normalized strings match, use it
3. **Fuzzy match** — if no exact match, find the closest Shopify title:
   - Strip common suffixes: " - Collection Content", " (New)", anything after " - " or " : "
   - Try matching the stripped version
   - If still no match, report as unmatched with the closest candidate

Present a match summary to the user before proceeding:

```
Matched 28 of 30 collections:
✓ "Jigsaw Puzzles - (New)" → "Jigsaw Puzzles"
✓ "1000 Piece Jigsaw Puzzles - Collection Content" → "1000 Piece Jigsaw Puzzles"
✗ "Joy Laforme New" — no match found. Did you mean "Joy Laforme"?
✗ "Christian Lacroix - Collection Content" — no match found.
```

**Wait for user confirmation** before creating any metaobjects. The user may want to fix unmatched names or skip them.

### Step 5 — Create FAQ metaobjects

Batch-create metaobjects using aliased mutations through shopifyProxy. See `references/faq-operations.md` for the Create FAQ Metaobject mutation pattern.

**Batching rules:**
- Max 25 aliased mutations per shopifyProxy call (Shopify limit)
- For 300 FAQs, this means ~12 calls
- Name aliases sequentially: `faq1`, `faq2`, ..., `faq25`

**Important:** Collect the returned metaobject GIDs grouped by resource — you'll need them for step 6.

**Error handling:** If any `userErrors` come back non-empty, log the failed FAQ (question text + error) and continue with the rest. Report failures at the end.

**Multi-message resilience:** Large imports (200+ FAQs) often span multiple chat messages due to tool-use limits. When resuming:
- Do NOT rely on local GID trackers from prior messages — they may be stale or incomplete.
- Before proceeding to step 6, verify the actual state by counting created metaobjects per collection using a read-back query (see step 6).
- If a batch was already executed in a prior message, its GIDs exist in Shopify even if the local tracker doesn't show them. Re-executing the same batch creates duplicates.

### Step 6 — Assign FAQs to resources

For each resource, set its FAQ metafield to reference the newly created metaobjects.

**Pre-assignment validation:** Before writing metafields, verify the GID count per collection matches the expected FAQ count from the CSV. If any collection has more GIDs than expected FAQs, duplicates were likely created — stop and flag this to the user before assigning. A simple check: `len(GIDs for collection) == len(FAQs for collection in CSV)`.

**Conflict handling** — check if the resource already has FAQs:

| Scenario | Default behavior |
|----------|-----------------|
| Resource has no existing FAQs | Create the metafield with the new GID array |
| Resource already has FAQs | **Ask the user**: append to existing, or replace? |

Read the current metafield value first using the Read Existing FAQ Assignments queries in `references/faq-operations.md`.

Then merge or replace, and write back via `metafieldsSet`. See `references/faq-operations.md` for the Assign FAQs to Resources mutation with variables pattern (required to avoid JSON escaping issues).

**Batching:** `metafieldsSet` accepts up to 25 metafields per call. Batch resource assignments accordingly.

### Step 7 — Report results

Present a clean summary:

```
✅ Import complete

Created: 290 FAQ items
Assigned to: 28 collections
Skipped: 2 collections (no match found)
Failed: 0

Collections with most FAQs:
  Jigsaw Puzzles — 10 FAQs
  1000 Piece Puzzles — 10 FAQs
  500 Piece Puzzles — 8 FAQs
  ...
```

For any unmatched resources, show them again with suggestions so the user can retry.

### Key gotchas

1. **JSON escaping** — never put the metafield `value` inline in triple-quoted GraphQL strings. Always use the `variables` parameter on `shopifyProxy` for `metafieldsSet`. See `references/faq-operations.md` for the pattern.

2. **Shopify indexing delay** — after creating metaobjects, there's a ~2 second delay before they're queryable. If you need to verify, add a brief wait.

3. **Metaobject type varies per store** — always discover it dynamically in step 2. Never hardcode `app--233074032641--risify_faq` or any specific app ID.

4. **Namespace for metafields** — the `faq` metafield namespace matches the app prefix. If the metaobject type is `app--234821386241--risify_faq`, the metafield namespace is `app--234821386241--risify`.

5. **Orphaned metaobjects** — if you create metaobjects but the assignment step fails, those metaobjects will exist unattached. Note this in the error report so the user can clean up.

6. **Large files (500+ FAQs)** — split into batches of 250 FAQs. Run steps 5-6 per batch to avoid timeouts. Show progress between batches.

7. **Duplicate detection** — the skill does NOT deduplicate. If a FAQ with the same question already exists as a metaobject, a new one will be created. Warn the user if they're importing to a collection that already has FAQs.

8. **Multi-message execution** — when imports span multiple chat messages (common for 200+ FAQs), the biggest risk is re-executing creation batches that already succeeded in a prior message. The local GID tracker resets between messages. Before resuming creation, verify which batches already completed by reading back a sample metaobject GID from the last known batch. If it exists, skip that batch. Before running assignment, validate GID counts per collection against the CSV to catch any duplication.
