# Audit GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool directly against the Risify API.

---

## Queries

### Check Audit Quota
```graphql
query {
  myAuditQuota {
    state
    message
    details {
      used
      limit
      remaining
      resetDate
    }
  }
}
```

State values: `ACTIVE`, `EXCEEDED`, `UNLIMITED`, `DISABLED`

### Get Current Audit
```graphql
query {
  currentAudit {
    id
    status
    createdAt
    updatedAt
  }
}
```

Status values: `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`

### List All Audits
```graphql
query {
  auditList {
    id
    status
    createdAt
    updatedAt
  }
}
```

### Get Audit Summary
```graphql
query {
  auditSummary(id: "<audit-id>") {
    healthScore
    onpageScore
    totalIssues
    highImpactIssues
    pagesChecked
    extendedCrawlStatus
    brokenLinks { name count trend { direction value } }
    metaIssues { name count trend { direction value } }
    schemaErrors { name count trend { direction value } }
    pageSpeedIssues { name count }
    nonIndexablePages { name count }
    pageSpeedMetrics {
      desktop {
        performanceScore
        lcp { value displayValue score }
        cls { value displayValue score }
        fcp { value displayValue score }
        tbt { value displayValue score }
        ttfb { value displayValue score }
        opportunities { id title displayValue score }
        diagnostics { id title displayValue }
      }
      mobile {
        performanceScore
        lcp { value displayValue score }
        cls { value displayValue score }
        fcp { value displayValue score }
        tbt { value displayValue score }
        ttfb { value displayValue score }
        opportunities { id title displayValue score }
        diagnostics { id title displayValue }
      }
    }
  }
}
```

### Get Broken Links (paginated)
```graphql
query {
  auditBrokenLinksConnection(args: {
    first: 20
    query: "auditId:<audit-id>"
    sortKey: LOCATION
  }) {
    nodes {
      id
      location
      issue
      url
      impact
      status
      statusCode
      details
    }
    pageInfo {
      hasNextPage
      endCursor
      totalCount
    }
  }
}
```

Filter by impact: `query: "auditId:<id> AND impact:HIGH"`

### Get Meta Issues (paginated)
```graphql
query {
  auditMetaIssuesConnection(args: {
    first: 20
    query: "auditId:<audit-id>"
    sortKey: IMPACT
  }) {
    nodes {
      id
      location
      issue
      url
      impact
      status
      details
    }
    pageInfo {
      hasNextPage
      endCursor
      totalCount
    }
  }
}
```

---

## Mutations

### Request New Audit
```graphql
mutation {
  requestAudit {
    id
    status
  }
}
```

### Download Audit Report
```graphql
mutation {
  downloadAudit(auditId: "<audit-id>") {
    filename
    data
    size
  }
}
```
