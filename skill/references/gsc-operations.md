# GSC GraphQL Operations Reference

Read-only analytics from Google Search Console. Pass `service: "gsc"` to `execute_graphql` and `introspect_schema` for every operation in this file **except** the connection-status checks at the top, which use the default `service: "risify"`.

---

## Connection status (service: "risify")

### Get connection info
```graphql
query {
  gscConnection {
    id
    status
    email
    siteUrl
    connectedAt
  }
}
```

### List connected sites
```graphql
query {
  gscSites {
    url
  }
}
```

---

## Analytics (service: "gsc")

### Summary
```graphql
query GscSummary($filter: GscFilter!) {
  gscSummary(filter: $filter) {
    TotalClicks
    TotalImpressions
    AvgCtr
    AvgPosition
    ClicksTrend { date value }
    ImpressionsTrend { date value }
  }
}
```

Variables:
```json
{
  "filter": {
    "StartDate": "2026-04-27",
    "EndDate": "2026-05-24"
  }
}
```

### Queries (top search terms)
```graphql
query GscQueries($filter: GscFilter!, $first: Int, $after: String) {
  gscQueries(filter: $filter, first: $first, after: $after) {
    nodes {
      query
      clicks
      impressions
      ctr
      position
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    totalCount
  }
}
```

Variables — non-branded queries, mobile, last 28 days, sorted by clicks server-side:
```json
{
  "filter": {
    "StartDate": "2026-04-27",
    "EndDate": "2026-05-24",
    "Device": "MOBILE",
    "QueryNotContains": "<brand>"
  },
  "first": 50
}
```

### Pages
```graphql
query GscPages($filter: GscFilter!, $first: Int, $after: String) {
  gscPages(filter: $filter, first: $first, after: $after) {
    nodes {
      page
      clicks
      impressions
      ctr
      position
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
    totalCount
  }
}
```

Variables — pages under a specific path, position 11–30:
```json
{
  "filter": {
    "StartDate": "2026-04-27",
    "EndDate": "2026-05-24",
    "PageContains": "/collections/",
    "QueryPositionMin": 11,
    "QueryPositionMax": 30
  },
  "first": 50
}
```

---

## `GscFilter` reference

| Field | Type | Notes |
|-------|------|-------|
| `StartDate` | `String!` | YYYY-MM-DD |
| `EndDate` | `String!` | YYYY-MM-DD |
| `Device` | `String` | `DESKTOP`, `MOBILE`, `TABLET` |
| `Country` | `String` | ISO country code (e.g. `USA`, `GBR`) |
| `QueryContains` | `String` | Case-insensitive substring filter on the query text |
| `QueryNotContains` | `String` | Substring to exclude — useful for non-branded filtering |
| `QueryPositionMin` | `Int` | Minimum average position |
| `QueryPositionMax` | `Int` | Maximum average position |
| `PageContains` | `String` | Substring filter on the page URL |

## Response shapes

### GscSummary
| Field | Type | Notes |
|-------|------|-------|
| `TotalClicks` | Int | Sum over range |
| `TotalImpressions` | Int | Sum over range |
| `AvgCtr` | Float | 0..1 (multiply by 100 for percent) |
| `AvgPosition` | Float | Lower is better |
| `ClicksTrend` | `[GscTrendPoint!]` | `{ date: String, value: Int }` |
| `ImpressionsTrend` | `[GscTrendPoint!]` | `{ date: String, value: Int }` |

### GscQueryRow / GscPageRow
| Field | Type | Notes |
|-------|------|-------|
| `query` (rows only) | String | Search term |
| `page` (pages only) | String | Page URL |
| `clicks` | Int | |
| `impressions` | Int | |
| `ctr` | Float | 0..1 |
| `position` | Float | Avg position |

## Pagination

All connections follow the Relay/Shopify pattern: `pageInfo { hasNextPage, endCursor }` plus `nodes`. To page forward, pass `after: pageInfo.endCursor`. Default `first` is server-defined — pass `first: 50` or `100` for analytics.

## Sorting

Analytics rows come pre-sorted by clicks descending. The MCP does not yet expose a `sortBy` arg — sort client-side after fetching enough pages.

## Notes

- Date freshness: Google typically lags 24–48 hours. A range that ends "today" may return less than expected.
- Empty result is normal for new sites or low-traffic stores.
- The connection JWT used by this service is minted transparently — you don't need to handle tokens.
- Mutations are not exposed here. Connection management (connect/disconnect/switch site) happens in the Risify Settings UI; if a user asks the agent to "connect GSC", direct them to that page.
