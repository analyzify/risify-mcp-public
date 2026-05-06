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
- **Risify API** — direct queries/mutations (e.g., `generateAIFAQ`, `aiCreditInfo`, `me`). Use this for most operations.
- **Shopify Admin API** — wrapped in `shopifyProxy(query: "...", variables: {...})` which proxies to Shopify through the Risify backend. No separate Shopify token needed. Use this only for direct Shopify operations (metaobject CRUD, metafield reads/writes, theme listing).

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
| "List all collections with products" / "Export collections" | → Collection Products Export flow |
| **Multi-step workflows** | **→ See `references/recipes.md`** |
| "Fix my SEO issues" / "Fix meta issues from audit" | Recipe 1: Audit → Fix Meta Issues |
| "Set up all navigation from scratch" | Recipe 11: Full Navigation Setup |
| "Set up SEO for my store" / "I'm new" | Recipe 13: Zero to Healthy |
| "Quick SEO wins" / "Fast improvements" | Recipe 14: Quick Start |
| "How's my SEO doing?" / "Compare audits" | Recipe 15: SEO Health Check |
| "What can I do with my credits?" | Recipe 16: Credit-Aware Planning |
| "This isn't working" / "I need help" | Recipe 17: Support Escalation |

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
