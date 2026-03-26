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
| FAQ Import | User wants to import, upload, or bulk-add FAQs from a CSV/Excel file | `references/faq-import.md` + `references/faq-import-operations.md` |

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
