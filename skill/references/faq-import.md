# Flow: FAQ Import from CSV/Excel

Import pre-written FAQ content from CSV/Excel files into a Shopify store by creating FAQ metaobjects and assigning them to collections, products, or pages — all through Risify's `shopifyProxy`.

## Architecture

FAQs are **Shopify Metaobjects** (type `$app:risify_faq`) with fields `question`, `answer`, `tags`. They are linked to resources via **metafields** (namespace `$app:risify`, key `faq`, type `list.metaobject_reference`).

- File parsing and resource matching happen client-side
- Metaobject creation and assignment use the **Shopify Admin API** via `shopifyProxy`
- The metaobject type prefix includes a store-specific app ID — always discover it dynamically

## Prerequisites

- Risify MCP connected with `execute_graphql` tool available
- The store must have the Risify FAQ metaobject definition installed
- User provides a CSV or Excel file with FAQ content

## Step-by-Step Flow

Follow these steps in order. Do not skip steps.

### Step 1: Parse the file

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

### Step 2: Discover the metaobject type

The metaobject type includes the Shopify app ID which varies per installation. Fetch it dynamically using the Discover Metaobject Type query in `faq-import-operations.md`.

Find the definition whose `type` ends with `risify_faq` (not `risify_faq_tag`). Extract the full type string (e.g. `app--234821386241--risify_faq`) and the namespace prefix (e.g. `app--234821386241--risify`).

Store both — you'll need the type for `metaobjectCreate` and the namespace for `metafieldsSet`.

### Step 3: Fetch resources for matching

Fetch all collections (or products) to build a title→GID map.

Use the List Collections / List Products queries in `faq-import-operations.md`. For stores with >250 collections, paginate with cursor.

### Step 4: Match resource names

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

### Step 5: Create FAQ metaobjects

Batch-create metaobjects using aliased mutations through shopifyProxy. See `faq-import-operations.md` for the Batch Create FAQ Metaobjects mutation pattern.

**Batching rules:**
- Max 25 aliased mutations per shopifyProxy call (Shopify limit)
- For 300 FAQs, this means ~12 calls
- Name aliases sequentially: `faq1`, `faq2`, ..., `faq25`

Collect the returned metaobject GIDs grouped by resource — you'll need them for step 6.

**Error handling:** If any `userErrors` come back non-empty, log the failed FAQ (question text + error) and continue with the rest. Report failures at the end.

**Multi-message resilience:** Large imports (200+ FAQs) often span multiple chat messages due to tool-use limits. When resuming:
- Do NOT rely on local GID trackers from prior messages — they may be stale or incomplete.
- Before proceeding to step 6, verify the actual state by counting created metaobjects per collection using the Read Existing FAQ Assignments query.
- If a batch was already executed in a prior message, its GIDs exist in Shopify even if the local tracker doesn't show them. Re-executing the same batch creates duplicates.

### Step 6: Assign FAQs to resources

For each resource, set its FAQ metafield to reference the newly created metaobjects.

**Pre-assignment validation:** Before writing metafields, verify the GID count per collection matches the expected FAQ count from the CSV. If any collection has more GIDs than expected FAQs, duplicates were likely created — stop and flag this to the user before assigning.

**Conflict handling** — check if the resource already has FAQs:

| Scenario | Default behavior |
|----------|-----------------|
| Resource has no existing FAQs | Create the metafield with the new GID array |
| Resource already has FAQs | **Ask the user**: append to existing, or replace? |

Read the current metafield value first using the Read Existing FAQ Assignments queries in `faq-import-operations.md`.

Then merge or replace, and write back via `metafieldsSet`. See `faq-import-operations.md` for the Assign FAQs to Resources mutation (always use variables to avoid JSON escaping issues).

**Batching:** `metafieldsSet` accepts up to 25 metafields per call. Batch resource assignments accordingly.

### Step 7: Report results

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

## Constants

| Key | Value |
|-----|-------|
| Metaobject type | `$app:risify_faq` (discover dynamically — app ID varies) |
| Metafield namespace | `$app:risify` (discover dynamically — app ID varies) |
| Metafield key | `faq` |
| Metafield type | `list.metaobject_reference` |
| Max aliased mutations per call | 25 |
| Max metafields per `metafieldsSet` | 25 |
| Large file batch size | 250 FAQs |

## Error Handling

| Situation | Response |
|-----------|----------|
| Column mapping ambiguous | Ask user to confirm column assignments |
| No match for resource name | Show closest candidate, ask user to fix or skip |
| metaobjectCreate userErrors | Log failed FAQ, continue with rest, report at end |
| metafieldsSet fails | Check ownerId validity and that metafield definition exists |
| Orphaned metaobjects | If assignment fails after creation, note unattached metaobjects in report |
| Duplicate risk | Warn user if importing to a collection that already has FAQs |
| Multi-message resume | Verify existing GIDs before resuming to avoid duplicate creation |

## Key Gotchas

1. **JSON escaping** — never put the metafield `value` inline in triple-quoted GraphQL strings. Always use the `variables` parameter on `shopifyProxy` for `metafieldsSet`.
2. **Shopify indexing delay** — after creating metaobjects, there's a ~2 second delay before they're queryable.
3. **Metaobject type varies per store** — always discover it dynamically in step 2. Never hardcode any specific app ID.
4. **Namespace for metafields** — the `faq` metafield namespace matches the app prefix. If the metaobject type is `app--234821386241--risify_faq`, the metafield namespace is `app--234821386241--risify`.
5. **Large files (500+ FAQs)** — split into batches of 250 FAQs. Run steps 5-6 per batch to avoid timeouts.
6. **Multi-message execution** — biggest risk is re-executing creation batches. Before resuming, verify which batches already completed by reading back a sample metaobject GID.
