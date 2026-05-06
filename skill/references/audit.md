# Flow: SEO Audit

Run SEO audits on the store, view health scores, broken links, meta issues, and page speed metrics.

## Step-by-Step Flow

### Step 1: Check Audit Quota

```graphql
query { myAuditQuota { state message details { used limit remaining resetDate } } }
```

- `state = ACTIVE` → can run audits, show remaining count
- `state = EXCEEDED` → monthly limit reached, tell user and stop
- `state = UNLIMITED` → no cap, proceed
- `state = DISABLED` → audits not available on this plan, suggest upgrade

### Step 2: Check for Existing Audit

```graphql
query { currentAudit { id status createdAt updatedAt } }
```

- If `status = COMPLETED` → ask user: "You have a recent audit. View results or run a new one?"
- If `status = PENDING` or `PROCESSING` → tell user: "An audit is already running. Check back in 1-3 minutes."
- If no audit exists or user wants a new one → proceed to Step 3

### Step 3: Request New Audit

```graphql
mutation { requestAudit { id status } }
```

Tell user: "SEO audit started. It typically takes 1-3 minutes. I'll check the results."

### Step 4: Check Status (if audit was just started)

```graphql
query { currentAudit { id status } }
```

- If `COMPLETED` → proceed to Step 5
- If still `PENDING` / `PROCESSING` → tell user to wait and check back

### Step 5: View Audit Summary

```graphql
query { auditSummary(id: "<audit-id>") { healthScore onpageScore totalIssues highImpactIssues pagesChecked brokenLinks { count } metaIssues { count } schemaErrors { count } pageSpeedIssues { count } nonIndexablePages { count } pageSpeedMetrics { desktop { performanceScore } mobile { performanceScore } } } }
```

ALWAYS present results using this template:

```text
SEO Audit Results:

  Health Score: {healthScore}/100
  On-Page Score: {onpageScore}/100
  Pages Checked: {pagesChecked}

Issues ({totalIssues} total, {highImpactIssues} high impact):
  Broken Links: {brokenLinks.count}
  Meta Issues: {metaIssues.count}
  Schema Errors: {schemaErrors.count}
  Page Speed: {pageSpeedIssues.count}
  Non-Indexable: {nonIndexablePages.count}

Performance:
  Desktop: {desktop.performanceScore}/100
  Mobile: {mobile.performanceScore}/100
```

### Step 6: Drill Down (if user asks)

**Broken links:**
```graphql
query { auditBrokenLinksConnection(args: { first: 20, query: "auditId:<audit-id>" }) { nodes { location issue url impact status statusCode } pageInfo { hasNextPage endCursor } } }
```

Present as:
```text
Broken Links:

1. [{impact}] {issue}
   URL: {url}
   Found on: {location}

2. ...
```

**Meta issues:**
```graphql
query { auditMetaIssuesConnection(args: { first: 20, query: "auditId:<audit-id>" }) { nodes { location issue url impact status details } pageInfo { hasNextPage endCursor } } }
```

### Step 7: Export (if user asks)

```graphql
mutation { downloadAudit(auditId: "<audit-id>") { filename data size } }
```

The `data` field contains the exported file content.

## Error Handling

| Situation | Response |
|-----------|----------|
| Quota exceeded | Show quota details, suggest plan upgrade |
| Audit still processing | Tell user to wait 1-3 minutes, offer to check again |
| Audit failed | Suggest re-running. If persistent, contact support |
| No audit exists | Offer to start a new audit |
