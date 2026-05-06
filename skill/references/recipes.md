# Cross-Flow Workflow Recipes

Multi-step workflows that chain features together. When a user's request spans multiple features, follow the matching recipe instead of improvising.

> **Recipe numbering:** the gaps in the sequence (1, 11, 11b, 13–18) are intentional. Omitted numbers correspond to multi-step flows that depend on features not yet shipped in the backend; they are deliberately not surfaced to avoid routing users to operations that don't work.

---

## Category 1: Audit-Driven Fixes

### Recipe 1: Audit → Fix Meta Issues

**Trigger:** "Find pages with missing meta titles and fix them", "Fix my meta issues from the audit", "Optimize meta tags for pages with SEO problems"

**Steps:**

1. Run or retrieve the latest audit (see `audit.md` Steps 1-5)
2. Drill into meta issues:
   ```graphql
   query { auditMetaIssuesConnection(args: { first: 50, query: "auditId:<audit-id>" }) { nodes { location issue url impact } pageInfo { hasNextPage endCursor totalCount } } }
   ```
3. Filter for issues mentioning "missing", "duplicate", or "too short/long" in the `issue` field
4. Match affected URLs to product/collection GIDs:
   - Extract handle from URL (e.g., `/products/blue-dress` → handle `blue-dress`)
   - Search products: `{ shopifyProductsConnection(args: { first: 5, query: "handle:blue-dress" }) { nodes { id title } } }`
   - Or collections: `{ shopifyCollectionsConnection(args: { first: 5, query: "handle:summer" }) { nodes { id title } } }`
5. Present findings: "{N} pages with meta issues found. Generate new meta tags for these?"
6. If user confirms → follow `meta.md` Steps 3-6 with the collected GIDs
7. After applying → offer: "Want me to re-run the audit to verify the fixes?"

**Flows involved:** Audit → Meta Tags → (optional) Audit

---

## Category 4: Navigation Pipeline

### Recipe 11: Full Navigation Setup

**Trigger:** "Set up all navigation for my store", "I want breadcrumbs, similar collections, and discover suggestions", "Configure navigation from scratch"

**Steps:**

1. Check AI credits
2. Check semantic sync status (see `navigation.md` Semantic Sync section)
3. If not synced: preview cost → trigger sync → inform user to wait
4. Once synced: list collections
5. Generate bulk recommendations for all collections (covers Breadcrumbs, Similar collections, Discover — collection-side only):
   ```graphql
   mutation { generateBulkRecommendations(collectionIds: [...], types: [BREADCRUMBS, COLLECTION_MENU, RELATED_SEARCH]) { results { collectionId breadcrumbs { id title handle score } collectionMenu { id title handle score } relatedSearch { id title handle score } } errors { collectionId message } totalProcessed totalCreditsUsed } }
   ```
   > Use these enum names (`BREADCRUMBS`, `COLLECTION_MENU`, `RELATED_SEARCH`) only inside the mutation. When speaking to the user, render them as **Breadcrumbs**, **Similar collections**, and **Discover** respectively.
6. Present recommendations grouped by collection → user accepts/dismisses
7. Apply accepted recommendations via shopifyProxy metafieldsSet (see `navigation-operations.md`)

**Flows involved:** Navigation (sync → generate → apply)

> **Caveat:** This recipe doesn't cover **Similar products** — that's a product-side feature with metafield key `related_products` and no `generateBulkRecommendations` enum. If the user wants product-side coverage, handle products separately via the manual Similar-products write path (see `navigation.md` → Similar products).

---

### Recipe 11b: Bulk import navigation data from a spreadsheet

**Trigger:** "Import this Excel/CSV into navigation", "Here's a spreadsheet of breadcrumbs / similar / discover entries — set them up", "Apply these related searches to all these collections", "Bulk-load discover suggestions from this file"

This is the marketing-team workflow: a spreadsheet maps owner resources (collections and/or products) to their Breadcrumbs, Similar collections, Similar products, and/or Discover suggestion entries. The danger zone is **Discover** — its value shape is `{title, url}` with handle-based URLs, NOT GIDs (see the Architecture table at the top of `navigation.md` for exact `type` per feature). Most bulk-import bugs come from substituting a GID where a `/collections/<handle>` URL belongs.

**Steps:**

1. **Parse the spreadsheet.** Identify, for each row:
   - The owner resource (collection or product) — by GID, handle, or title.
   - Which feature(s) the row's entries are for. Note the per-feature owner constraints:
     - **Breadcrumbs**: collections or products
     - **Similar collections** (`collection_menu`): collections only; targets are collections
     - **Similar products** (`related_products`): products only; targets are products
     - **Discover suggestions** (`related_searches`): collections or products; targets can be collections or products (handle-based URLs)
   - The target resources for each entry — by GID, handle, or title.

2. **Resolve every owner and every target to BOTH `gid` AND `handle`.** This is the step that prevents the GID-in-Discover bug. Run a paginated query once and build a lookup map:

   ```graphql
   # Via shopifyProxy
   query { collections(first: 250) { nodes { id handle title } pageInfo { hasNextPage endCursor } } }
   ```

   Continue paginating with `after: <endCursor>`. Repeat with `products` if products are involved. Build a map keyed by whichever identifier the spreadsheet provided (handle or title) so every row ends up with both `gid` and `handle` available. If the spreadsheet only has GIDs, build the inverse map (gid → handle).

   If any target resource cannot be resolved (handle missing, GID stale): collect those rows into a "could not resolve" list and surface them at the end. Do not write `null`/empty values into the metafield.

3. **Build per-feature payloads — one payload shape per feature, side by side.** Do not generalize across features. The four shapes are:

   ```js
   // Breadcrumbs — collection-GID array (works for collection or product owners)
   {
     ownerId: ownerGid,
     namespace: "$app:risify",
     key: "breadcrumb",
     type: "list.collection_reference",
     value: JSON.stringify([targetCollectionGid1, targetCollectionGid2, ...])
   }

   // Similar collections — collection-GID array (collection owners only)
   {
     ownerId: ownerCollectionGid,
     namespace: "$app:risify",
     key: "collection_menu",
     type: "list.collection_reference",
     value: JSON.stringify([targetCollectionGid1, targetCollectionGid2, ...])
   }

   // Similar products — product-GID array (product owners only)
   //   Note: different metafield key AND different type than Similar collections
   {
     ownerId: ownerProductGid,
     namespace: "$app:risify",
     key: "related_products",
     type: "list.product_reference",
     value: JSON.stringify([targetProductGid1, targetProductGid2, ...])
   }

   // Discover suggestions — {title, url} objects (collection or product owners)
   //   url MUST be /collections/<handle> or /products/<handle>
   //   url MUST NOT be a GID, an absolute URL, or locale-prefixed
   {
     ownerId: ownerGid,
     namespace: "$app:risify",
     key: "related_searches",
     type: "json",
     value: JSON.stringify(entries.map(e => ({
       title: e.title,
       url: (e.targetType === "product" ? "/products/" : "/collections/") + e.targetHandle
     })))
   }
   ```

4. **Batch the `metafieldsSet` calls.** Shopify caps at 25 metafields per call — chunk the input array accordingly. Report per-batch success/failure with collection IDs and any `userErrors`. Continue past partial failures so one bad row doesn't abort the rest.

5. **Verify after writing.** Re-read each touched metafield via `shopifyProxy` and confirm the persisted value matches the contract for that feature. For Discover specifically:

   ```regex
   ^/(collections|products)/[a-z0-9-]+$
   ```

   Every entry's `url` must match. If any don't, surface them — that's a sign step 2's lookup missed something or step 3 used the wrong identifier.

**Common mistakes to avoid:**

- **Do NOT** put GIDs into Discover entries. Discover is the only one of these features that does not take GIDs. If you find yourself writing `{"title": "...", "url": "gid://shopify/..."}`, stop — go back to your lookup map from step 2 and use the `handle` instead.
- **Do NOT** reuse the GID-array shape from Breadcrumbs / Similar collections / Similar products for Discover. The metafield `type` is different (`json` vs `list.collection_reference` / `list.product_reference`), and Shopify will silently accept whatever string you put in `value` as long as the type matches — bad data goes through.
- **Do NOT** mix product GIDs into a Similar collections payload (or collection GIDs into Similar products). The metafield `type` rejects the wrong reference shape, but if you also pass the wrong `type`, the write succeeds with corrupt data. Match owner type, key, type, and target reference shape strictly.
- **Do NOT** use absolute URLs (`https://shop.myshopify.com/collections/x`) or locale-prefixed URLs (`/en-us/collections/x`) in Discover. The storefront block prepends the store domain itself, and locale prefixes break theme-level routing.

**Flows involved:** Navigation (lookup → write → verify), no AI suggestions involved

---

## Category 5: New Store Onboarding

### Recipe 13: Zero to Healthy (Complete Onboarding)

**Trigger:** "Set up SEO for my store from scratch", "I'm new, what should I do?", "Help me get started with Risify", "Complete SEO setup"

**Steps:**

1. **Account check:** `{ me { shopName isAppSubscriptionPlanActive } }` + `{ aiCreditInfo { limit usage } }` → verify subscription and credits
2. **Run first audit:** Follow `audit.md` → present health score as baseline
3. **Fix critical issues:** If broken links > 0 → list top 5 → suggest support ticket (see services.md)
4. **Fix meta issues:** If meta issues > 0 → follow Recipe 1 (audit → fix meta)
5. **Generate FAQs:** List top 20 products → generate 3 FAQs each → review → save (see `faq.md`)
6. **Set up navigation:** Follow Recipe 11 (full navigation setup)
7. **Final report:**
   ```text
   Store SEO Setup Complete!

   Baseline Health Score: {before}/100
   Actions Taken:
     ✓ SEO audit completed
     ✓ {N} meta tags optimized
     ✓ {F} FAQs created across {R} resources
     ✓ Navigation configured for {C} collections
     ✓ {issues} critical issues reported to support

   Next: Re-run your audit in a few days to see improvement.
   ```

**Flows involved:** Account → Audit → Meta Tags → FAQ → Navigation

---

### Recipe 14: Quick Start (Minimum Viable SEO)

**Trigger:** "Quick SEO wins", "What's the fastest way to improve my SEO?", "I only have a few minutes"

**Steps:**

1. Check credits
2. **Meta tags for top products:** List first 20 products → `bulkGenerateAIMeta` → review → apply
3. **FAQs for top 10:** `generateAIFAQ` for first 10 products, 3 each → review → `bulkCreateAndAssignFaqs`
4. **Run audit:** Get baseline score
5. Summary: "Quick wins applied: {N} meta tags + {F} FAQs. Health score: {score}/100."

**Flows involved:** Meta Tags → FAQ → Audit

---

## Category 6: Monitoring & Maintenance

### Recipe 15: SEO Health Check

**Trigger:** "How's my SEO doing?", "Check my SEO health", "Any new issues?", "Compare with last audit"

**Steps:**

1. Get current audit: `{ currentAudit { id status createdAt } }`
2. Get audit list for trend comparison: `{ auditList { id status createdAt } }`
3. If latest audit is old (>7 days) → offer to run a new one
4. Fetch summary for latest + previous audit
5. Compare and present trends:
   ```text
   SEO Health Check:

   Current Score: {current}/100 (was {previous}/100)
   Trend: {direction} {delta} points

   Category Trends:
     Broken Links: {current} (was {previous}) {arrow}
     Meta Issues: {current} (was {previous}) {arrow}
     Schema Errors: {current} (was {previous}) {arrow}
     Page Speed: {current} (was {previous}) {arrow}

   Suggested Actions:
     {list top 3 improvement opportunities based on biggest issue categories}
   ```

**Flows involved:** Audit (current + historical comparison)

---

### Recipe 16: Credit-Aware Operation Planning

**Trigger:** "How many credits do I have left?", "What can I do with my remaining credits?", "Plan my credit usage"

**Steps:**

1. Check credits: `{ aiCreditInfo { limit usage resetAt } }`
2. Calculate remaining
3. Present options ranked by impact per credit:
   ```text
   AI Credits: {remaining} remaining (resets {resetAt})

   What you can do:
     Meta Tags: ~{remaining} products (1 credit each)
     FAQs: ~{remaining/count} batches of {count} FAQs (1 credit per resource)
     Navigation Sync: ~{remaining * collectionsPerCredit} collections

   Recommendation: {highest-impact suggestion based on store state}
   ```

**Flows involved:** Account → (any feature based on budget)

---

## Category 7: Support Workflows

### Recipe 17: Feature Issue → Support Escalation

**Trigger:** "This isn't working", "I keep getting errors", "Something is broken", "I need help"

**Steps:**

1. Identify which feature is failing (from conversation context)
2. Collect error details from the last failed operation
3. Get account context: `{ me { shopName domain email } }`
4. Create support ticket with full context:
   ```graphql
   mutation { createSupportTicket(input: { topic: "Issue with {feature name}" message: "Store: {shopName} ({domain})\n\nIssue: {description of the problem}\n\nError: {error message from failed operation}\n\nSteps taken: {what was attempted}" }) }
   ```
5. Confirm: "Support ticket created. The Risify team will respond to {email}."

**Flows involved:** (any feature) → Support

---

## Category 8: Data Export

### Recipe 18: Collection Products Export

**Trigger:** "List all collections with their products", "Export collections and products", "Show me what's in each collection", "Collection product breakdown"

**Steps:**

1. List all collections with pagination:
   ```graphql
   { shopifyCollectionsConnection(args: { first: 250 }) { nodes { id title handle productsCount } pageInfo { hasNextPage endCursor } } }
   ```
   Keep paginating with `after` until `hasNextPage` is false. Collect all collection GIDs and titles.

2. For each collection, fetch its products via shopifyProxy:
   ```graphql
   { shopifyProxy(query: "query ($id: ID!, $first: Int!, $after: String) { collection(id: $id) { id title products(first: $first, after: $after) { nodes { id title handle status } pageInfo { hasNextPage endCursor } } } }" variables: { "id": "<collection-GID>", "first": 50 }) { data errors } }
   ```
   Paginate within each collection if it has more than 50 products.

3. Present results grouped by collection:
   ```text
   {Collection Title} ({productsCount} products):
     1. {product title} — {handle}
     2. {product title} — {handle}
     ...

   {Next Collection Title} ({productsCount} products):
     1. {product title} — {handle}
     ...
   ```

4. If the user wants a summary instead of full listing, present:
   ```text
   Collections Overview ({total} collections):

   1. {title} — {productsCount} products
   2. {title} — {productsCount} products
   ...

   Total: {sum} products across {total} collections
   ```

**Note:** For stores with many collections, this requires one API call per collection. Process in batches and show progress: "Fetched products for {N} of {total} collections..."

**Flows involved:** Shopify data export (collections + products)
