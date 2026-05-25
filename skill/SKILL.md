---
name: risify
description: >
  Complete skill for the Risify Shopify SEO app. Covers all Risify features and workflows.
  Trigger when the user wants to: generate FAQs, manage FAQs, list FAQs,
  import FAQs from CSV/Excel, bulk-add FAQs, upload FAQ files,
  run SEO audits, check SEO health, view broken links, view meta issues,
  generate meta tags, optimize meta titles/descriptions,
  view account info, check AI credits, manage subscription/billing/plans,
  add/edit/remove team contacts, view billing history, cancel subscription, upgrade plan,
  assign FAQs to products or collections,
  manage breadcrumbs, set up similar collections, set up similar products, configure discover suggestions (legacy: related searches),
  generate AI navigation recommendations, activate navigation features, sync collections for AI,
  open support tickets, manage service requests,
  fix SEO issues from audit, optimize products for SEO, bulk SEO sweep,
  set up SEO from scratch, quick SEO wins, compare audits,
  analyze Google Search Console performance, view GSC data, show top search queries,
  find pages losing traffic, check click-through rate, see search impressions and clicks,
  identify CTR opportunities, compare branded vs non-branded queries, week-over-week position changes,
  view tracked keywords, list keyword catalogues, show ranking history, find biggest gainers and losers,
  check keyword position distribution, see newly discovered keywords, ranking trends over time,
  or any Risify-related task. Covers questions like: "generate FAQs for my products",
  "import FAQs", "upload FAQs from CSV", "bulk add FAQs", "add FAQs from file",
  "import questions and answers", "add these FAQs to my collections",
  "what plan am I on", "how many credits do I have", "add a team member",
  "show my billing history", "cancel my subscription", "list my FAQs",
  "set up breadcrumbs", "suggest breadcrumbs with AI",
  "set up similar collections" (legacy alias: "add collection menu"),
  "configure discover suggestions" (legacy alias: "configure related searches"),
  "generate navigation recommendations",
  "top GSC queries", "pages losing traffic", "click-through rate",
  "search impressions", "search console summary", "branded vs non-branded queries",
  "tracked keywords", "keyword rankings", "ranking history", "position changes",
  "biggest gainers", "biggest losers", "keyword discoveries", "what keywords am I tracking",
  "which keywords dropped", "ranking distribution".
  All operations use the execute_graphql MCP tool. GSC analytics and Keyword
  Tracking data live on separate services — pass `service: "gsc"` or
  `service: "keyword"` to execute_graphql / introspect_schema when working
  with those domains.
---

# Risify MCP Skill

Complete workflow guide for the Risify Shopify SEO platform. All operations go through the `execute_graphql` MCP tool.

**Four data domains, one tool (`execute_graphql`).** Pick the right `service` per call:

- **Risify API** — `service: "risify"` (default; you can omit it). Direct queries/mutations (e.g., `generateAIFAQ`, `aiCreditInfo`, `me`, `gscConnection`, `gscSites`). Use this for most operations.
- **Shopify Admin API** — `service: "risify"` with `shopifyProxy(query: "...", variables: {...})` wrapper. Proxies to Shopify through the Risify backend. No separate Shopify token needed. Use only for direct Shopify operations (metaobject CRUD, metafield reads/writes, theme listing).
- **Google Search Console analytics** — `service: "gsc"`. Read-only analytics: `gscSummary`, `gscQueries`, `gscPages`. See `references/gsc.md`. Connection status checks (`gscConnection`, `gscSites`) stay on `service: "risify"`.
- **Keyword Tracking** — `service: "keyword"`. Read-only: catalogues, tracked items, position snapshots, gainers/losers, history, keyword discoveries. See `references/keywords.md`. Writes are intentionally not exposed in this release — direct the user to the Risify Keyword Tracking page for adds/edits.

**UI labels vs API names** — the product UI uses friendly labels that differ from metafield keys and GraphQL enums. Always speak the UI label to the user; use the metafield key / enum only inside queries. Old labels that MUST NOT appear in user-facing strings:
- "Related Searches" → say **"Discover"** / **"Discover suggestions"** (metafield key stays `related_searches`, works on both Collection and Product owner types; bulk-AI enum is `RELATED_SEARCH` — collection-only)
- "Collection Menu" → say **"Similar collections"** (metafield key stays `collection_menu`, enum stays `COLLECTION_MENU`)
- Product-side "Similar" is a separate feature with metafield key `related_products` (no GraphQL enum — no AI bulk-gen, manual writes only)

## Request Routing

Match the user's request to the right flow:

| User says... | Flow |
|---|---|
| "Generate FAQs for my products" | FAQ → full flow |
| "Show my FAQs" / "List FAQs" | FAQ → List Existing FAQs |
| "Update this FAQ" / "Edit FAQ" | FAQ → Update FAQ |
| "Delete this FAQ" | FAQ → Delete FAQ |
| "Import FAQs from CSV/Excel" / "Upload FAQs" / "Bulk add FAQs" | FAQ Import → full flow |
| "Run an SEO audit" / "Check my SEO" | Audit → full flow |
| "Show audit results" / "Broken links?" | Audit → View results |
| "Generate meta tags" / "Optimize titles" | Meta Tags → full flow |
| "What plan am I on?" / "Account info" | Account → View Account |
| "How many credits do I have?" | Account → Check Credits |
| "Add a team member" | Account → Add Contact |
| "Show billing history" | Account → Billing |
| "Cancel my subscription" | Account → Cancel |
| "Set up breadcrumbs" | Navigation → Breadcrumbs |
| "Generate navigation recommendations" | Navigation → Bulk AI |
| "Set up Discover" / "Add discover suggestions" / "Edit related searches" (legacy) | Navigation → Discover |
| "Add similar collections" / "Set up similar" (on a collection) | Navigation → Similar collections |
| "Show related products" / "Set up similar products" (on a product) | Navigation → Similar products |
| "Open a support ticket" | Support → Create Ticket |
| "Show my Search Console data" / "GSC summary" / "Clicks and impressions last 28 days" | GSC → Summary |
| "Top GSC queries" / "Best search queries" / "What am I ranking for?" | GSC → Top Queries |
| "Pages losing traffic" / "Top GSC pages" / "Which pages get the most search clicks" | GSC → Top Pages |
| "CTR opportunities" / "High impressions low CTR" / "Queries that don't get clicked" | GSC → CTR Opportunities |
| "Branded vs non-branded queries" | GSC → Top Queries (with `QueryNotContains: <brand>`) |
| "Position changes week over week" / "Which queries moved up or down" | GSC → Position Changes |
| "Connect GSC" / "Disconnect Search Console" | Tell user this happens in Risify Settings → Search Console; don't try to do it from MCP |
| "List my catalogues" / "Show keyword catalogues" / "What am I tracking?" | Keywords → List catalogues |
| "Tracked keywords" / "Show keywords in catalogue X" | Keywords → List items |
| "Biggest gainers" / "Biggest losers" / "Which keywords improved this week" | Keywords → Movers |
| "Ranking history for keyword X" / "Position history" | Keywords → History |
| "Ranking distribution" / "How many in top 10" / "Position trend" | Keywords → Distribution / Trend |
| "New keyword discoveries" / "What new keywords am I ranking for" | Keywords → Discoveries |
| "Add keyword X to tracking" / "Stop tracking Y" / "Tag these keywords" | Tell user to use the Risify Keyword Tracking page — writes not exposed in this release |
| "List all collections with products" / "Export collections" | Recipe 18: Collection Products Export |
| **Multi-step workflows** | **→ See `references/recipes.md`** |
| "Fix my SEO issues" / "Fix meta issues from audit" | Recipe 1: Audit → Fix Meta Issues |
| "Set up all navigation from scratch" | Recipe 11: Full Navigation Setup |
| "Set up SEO for my store" / "I'm new" | Recipe 13: Zero to Healthy |
| "Quick SEO wins" / "Fast improvements" | Recipe 14: Quick Start |
| "How's my SEO doing?" / "Compare audits" | Recipe 15: SEO Health Check |
| "What can I do with my credits?" | Recipe 16: Credit-Aware Planning |
| "This isn't working" / "I need help" | Recipe 17: Support Escalation |
| "Pages losing clicks despite rankings" / "High-impression low-CTR pages" / "Meta refresh from Search Console" | Recipe 19: High-impression low-CTR pages → meta-tag refresh |
| "FAQ ideas from search" / "What questions are people searching for" / "Turn GSC queries into FAQs" | Recipe 20: GSC question-shaped queries → FAQ candidates |
| "Prioritize audit issues by traffic" / "Which audit issues matter most" / "Fix what has traffic" | Recipe 21: GSC-prioritized audit issues |
| "Why did my keywords drop" / "Investigate keyword ranking drops" / "Audit pages for keywords that fell" | Recipe 22: Tracked keyword drops → landing-page audit + meta refresh |

## Available Flows

| Flow | Trigger | Reference |
|------|---------|-----------|
| FAQ Generation & Assignment | Generate, create, list, update, delete, or assign FAQs | `references/faq.md` + `references/faq-operations.md` |
| FAQ Import | User wants to import, upload, or bulk-add FAQs from a CSV/Excel file | `references/faq-import.md` + `references/faq-import-operations.md` |
| SEO Audit | Run audits, view health scores, broken links, meta issues, page speed | `references/audit.md` + `references/audit-operations.md` |
| Meta Tags | Generate AI meta titles/descriptions for products/collections | `references/meta.md` + `references/meta-operations.md` |
| Account Management | Account info, billing, plans, contacts, credits, subscription | `references/account.md` + `references/account-operations.md` |
| Navigation | Breadcrumbs, Similar (collections + products), Discover suggestions, AI suggestions | `references/navigation.md` + `references/navigation-operations.md` |
| Support & Services | Support tickets, service requests | `references/services.md` + `references/services-operations.md` |
| Google Search Console | Analyze GSC clicks, impressions, CTR, position; top queries/pages; movers (read-only) | `references/gsc.md` + `references/gsc-operations.md` |
| Keyword Tracking & Discovery | Catalogues, tracked-keyword rankings, position history, gainers/losers, discoveries (read-only) | `references/keywords.md` + `references/keywords-operations.md` |
| **Cross-Flow Recipes** | Multi-step workflows that chain features (audit→fix, full product SEO, onboarding) | `references/recipes.md` |

## How to Use

1. Match the user's request to a flow using the routing table above
2. Load the corresponding reference files
3. Follow the step-by-step flow in the reference file
4. Present results using the templates provided
5. If a flow requires AI credits, always check credits first

## Error Handling

| Error | Meaning | Action |
|-------|---------|--------|
| Auth error / 401 / 403 | Credentials invalid or expired | Tell user to check RISIFY_USER_ID and RISIFY_API_KEY in MCP settings |
| "insufficient credits" / "credit" errors | AI credits exhausted | Show current balance, suggest plan upgrade or wait for monthly reset |
| shopifyProxy errors | Shopify API issue | Check inner `errors` array for details, retry once, then report to user |
| Partial failures (successCount < total) | Some items succeeded, some failed | Report successes, list failures with specific reasons, ask if user wants to retry failed items |
| "feature not activated" | Missing metafield definitions | Guide user through feature activation (see navigation.md) |
| Quota exceeded (audits) | Monthly audit limit reached | Show quota info, suggest plan upgrade |
| GSC analytics call fails with auth error | Search Console not connected or token expired | Check `gscConnection` (on `service: "risify"`); if not connected, tell user to set it up in Risify Settings → Search Console |
| GSC empty result | No data for the chosen range | Mention Google has ~48h reporting lag; suggest widening the range |
| Keyword call fails with subscription error | Keyword Tracking requires an active paid plan | Show plan info from `me`/`appSubscriptionCharge`; suggest upgrade |
| Keyword `catalogues` returns 0 | User hasn't set up tracking yet | Tell them to create a catalogue from the Risify Keyword Tracking page |

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

**Get Products in a Collection (via shopifyProxy):**
```graphql
{ shopifyProxy(query: "query ($id: ID!, $first: Int!, $after: String) { collection(id: $id) { id title products(first: $first, after: $after) { nodes { id title handle status } pageInfo { hasNextPage endCursor } } } }" variables: { "id": "gid://shopify/Collection/123", "first": 50 }) { data errors } }
```

**List Existing FAQs:**
```graphql
{ shopifyProxy(query: "query ($type: String!, $first: Int) { metaobjects(type: $type, first: $first) { nodes { id handle fields { key value } } pageInfo { hasNextPage endCursor } } }" variables: { "type": "$app:risify_faq", "first": 20 }) { data errors } }
```

## Long-Running Tasks

Some operations (bulk FAQ generation, bulk meta generation, bulk recommendations) support async execution with progress polling. The pattern:

1. **Start:** Call the `start*` mutation → returns `taskId`
2. **Poll:** Call `generationTaskStatus(taskId)` every 3-5 seconds → check `status` and `progress.percent`
3. **Results:** When status is `COMPLETED`, call `generationTaskResults(taskId)` → get final data

Task statuses: `CREATED` → `RUNNING` → `COMPLETED` (or `FAILED` / `COMPLETED_WITH_ERRORS`)

See `references/meta-operations.md` for async meta generation examples.
