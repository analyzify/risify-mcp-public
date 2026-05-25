# GSC GraphQL Operations Reference

Read-only analytics from Google Search Console via the reportgo service. Pass `service: "gsc"` to `execute_graphql` and `introspect_schema` for every analytics operation in this file. Connection-status and token-mint operations use the default `service: "risify"`.

Default to the **v2 surface** (`v2ScAnalytics`, `v2ScQueries`, `v2ScPages`). Drop to **v1** (`scTraffics`, `scTrafficsPaginated`, `scAnalytics`) only when you need custom `groupByFields`, substring filters, country/device filters, or time-series breakdown.

---

## Connection status (service: "risify")

### Get connection info + reTaskId
```graphql
query {
  gscConnection {
    id
    status
    email
    siteUrl
    reTaskId
    connectedAt
  }
}
```

`reTaskId` is the GSC sync task identifier on reportgo. Save it; every analytics call needs it as `default.taskId`.

### List connected sites
```graphql
query {
  gscSites { url }
}
```

### Mint a space token (to derive spaceId)
```graphql
mutation { reportGetSpaceToken }
```

Returns a JWT. Decode the middle segment (base64url-decode → JSON-parse) and read the `sub` claim — that's the `spaceId` reportgo expects as `default.spaceId` for every analytics call. **It is NOT the Risify user id.**

Cache `spaceId` and `taskId` for the whole conversation; don't re-fetch them per query.

---

## v2 surface (default — use this)

### `v2ScAnalytics` — summary + per-day rows

```graphql
query V2ScAnalytics($input: V2ScAnalyticsInput!) {
  v2ScAnalytics(input: $input) {
    meta { source reportKey accountLabel timezone }
    summary { clicks impressions ctr position }
    rows { dated clicks impressions ctr position }
    comparison { summary { clicks impressions ctr position } rows { dated clicks impressions ctr position } }
  }
}
```

Variables — 28-day summary, no comparison:
```json
{ "input": {
  "default": {
    "spaceId": "<from-jwt-sub>",
    "taskId":  "<from-gscConnection.reTaskId>",
    "startDate": "2026-04-27",
    "endDate":   "2026-05-24"
  }
}}
```

Variables — 28-day vs prior 28-day comparison:
```json
{ "input": {
  "default":    { "spaceId":"<...>", "taskId":"<...>", "startDate":"2026-04-27", "endDate":"2026-05-24" },
  "comparison": { "spaceId":"<...>", "taskId":"<...>", "startDate":"2026-03-30", "endDate":"2026-04-26" }
}}
```

### `v2ScQueries` — top queries

```graphql
query V2ScQueries($input: V2ScQueriesInput!) {
  v2ScQueries(input: $input) {
    summary { clicks impressions ctr position }
    rows { query clicks impressions ctr position }
    pageInfo { page limit totalCount totalPages hasNextPage }
    comparison { summary { clicks impressions ctr position } rows { query clicks impressions ctr position } }
  }
}
```

Variables — top 50 by impressions:
```json
{ "input": {
  "default": {
    "spaceId":"<...>", "taskId":"<...>",
    "startDate":"2026-04-27", "endDate":"2026-05-24",
    "orderByFields": ["-impressions"],
    "limit": 50,
    "page": 1
  }
}}
```

`orderByFields` syntax: `-fieldName` for DESC, `fieldName` for ASC. Valid keys: `clicks`, `impressions`, `ctr`, `position`.

### `v2ScPages` — top pages

```graphql
query V2ScPages($input: V2ScPagesInput!) {
  v2ScPages(input: $input) {
    summary { clicks impressions ctr position }
    rows { pageUrl clicks impressions ctr position }
    pageInfo { page limit totalCount totalPages hasNextPage }
    comparison { summary { clicks impressions ctr position } rows { pageUrl clicks impressions ctr position } }
  }
}
```

Variables — top 50 pages by clicks:
```json
{ "input": {
  "default": {
    "spaceId":"<...>", "taskId":"<...>",
    "startDate":"2026-04-27", "endDate":"2026-05-24",
    "orderByFields": ["-clicks"],
    "limit": 50,
    "page": 1
  }
}}
```

---

## v1 surface (advanced — only when you need extra dimensions)

### `scAnalytics` — aggregated metrics with custom dimensions

```graphql
query ScAnalytics($input: ScAnalyticInput!) {
  scAnalytics(input: $input) {
    dated year quarter month week day
    clicks impressions ctr position
  }
}
```

Use this when you need a daily time series with custom grouping. With `groupByFields: []` + `groupByDate: false` you get a single row (equivalent to `v2ScAnalytics` summary); the value of v1 here is `groupByDate: true` plus `dateArgs`.

Variables — daily time series for 60 days:
```json
{ "input": {
  "default": {
    "spaceId":"<...>", "taskId":"<...>",
    "startDate":"2026-03-25", "endDate":"2026-05-24",
    "groupByFields": [],
    "groupByDate": true,
    "dateArgs": [{ "groupBy": "DAY", "orderBy": "ASC" }]
  }
}}
```

`Calendar` enum: `YEAR`, `MONTH`, `QUARTER`, `WEEK`, `DAY`.

### `scTrafficsPaginated` — paginated rows with custom dimensions and filters

```graphql
query ScTrafficsPaginated($input: ScTrafficInput!) {
  scTrafficsPaginated(input: $input) {
    totalCount totalPage currentPage
    nodes { dated queried urlId countryIso3 deviceId clicks impressions ctr position }
  }
}
```

Use this when v2 doesn't expose what you need: query × device, page × country, branded vs non-branded splits, position-range filters, etc.

Variables — top 50 mobile non-branded queries:
```json
{ "input": {
  "default": {
    "spaceId":"<...>", "taskId":"<...>",
    "startDate":"2026-04-27", "endDate":"2026-05-24",
    "groupByFields": ["queried"],
    "orderByFields": ["clicks DESC"]
  },
  "deviceId": 2,
  "brandFilter": "NON_BRANDED",
  "brandRules": [{ "operator": "CONTAINS", "value": "saint bernard" }],
  "limit": 50, "page": 1
}}
```

Note v1's `orderByFields` syntax is `"<field> DESC|ASC"` (space-separated), unlike v2's `-fieldName`.

### `scTraffics` — un-paginated rows (use only for small expected result sets)

Same as `scTrafficsPaginated` minus the pagination wrapper. Returns `[ScTraffic!]!` directly. Skip in favor of the paginated variant unless you know the result set is small.

### `scBrandRules` / `scBrandRulesUpdate`

Read or write the brand-rule list for the SC task. Read:
```graphql
query ScBrandRules($taskId: String!) { scBrandRules(taskId: $taskId) { operator value } }
```
Write (rarely needed via MCP — confirm with the user first):
```graphql
mutation ScBrandRulesUpdate($taskId: String!, $input: ScBrandRulesUpdateInput!) {
  scBrandRulesUpdate(taskId: $taskId, input: $input) { operator value }
}
```

---

## Input shapes

### `StandardQueryInput` (the `default` and `comparison` blocks)

```graphql
input StandardQueryInput {
  startDate: String          # YYYY-MM-DD
  endDate: String            # YYYY-MM-DD
  spaceId: String!           # from reportGetSpaceToken JWT sub
  taskId: String             # from gscConnection.reTaskId
  refId: String              # optional reference id
  dateArgs: [DateArgs]       # v1 time-series only
  groupByDate: Boolean       # v1 time-series only
  orderByFields: [String!]   # v2: "-field" / "field"; v1: "field DESC"/"field ASC"
  groupByFields: [String!]   # v1 only — keys: queried, url_id, country_iso3, device_id
  limit: Int                 # paginated outputs only
  page: Int                  # paginated outputs only (1-indexed)
}
```

### `V2ScAnalyticsInput` / `V2ScQueriesInput` / `V2ScPagesInput`

```graphql
input V2ScAnalyticsInput {
  default: StandardQueryInput!
  comparison: StandardQueryInput
}
```

All three v2 inputs have the identical shape — only the output differs (analytics has date rows, queries has query rows, pages has pageUrl rows).

### `ScTrafficInput` (v1 advanced — top-level filters)

| Field | Type | Notes |
|---|---|---|
| `default` | `StandardQueryInput!` | Required |
| `queryExact` | `String` | Exact (case-insensitive) |
| `queryContains` | `String` | Substring |
| `queries` | `[String!]` + `queryOperator: AND \| OR` | Multi-term |
| `pageExact` | `String` | Exact URL |
| `pageContains` | `String` | Substring |
| `pageTypes` | `[PageType!]` | Risify page-type filter |
| `countryIso3` | `String` | ISO3 country |
| `deviceId` | `Uint32` | 1=desktop, 2=mobile, 3=tablet |
| `positionMin` / `positionMax` | `Float` | Avg position range |
| `brandFilter` | `BrandFilter` | `BRANDED` / `NON_BRANDED` |
| `brandRules` | `[ScBrandRuleInput!]` | Inline rules `{ operator, value }` |
| `limit` / `page` | `Int` | Paginated variant only |
| `sort` | `[ScTrafficSort!]` | Type-safe sort (overrides `default.orderByFields`) |

---

## Response shapes

### `V2ScAnalyticsSummary` (used by every v2 query)

```graphql
type V2ScAnalyticsSummary {
  clicks: Float!
  impressions: Float!
  ctr: Float!       # percent value (0.71 = 0.71%)
  position: Float!  # average position; lower is better
}
```

**Field names are flat — there is no `totalClicks` / `averageCtr`.** This is the most common source of `Cannot query field` errors.

### `V2ScAnalyticsRow` (v2 analytics)
```graphql
type V2ScAnalyticsRow {
  dated: Date!
  clicks: Float!
  impressions: Float!
  ctr: Float!
  position: Float!
}
```

### `V2ScQueryRow` (v2 queries)
```graphql
type V2ScQueryRow {
  query: String!
  clicks: Float!
  impressions: Float!
  ctr: Float!
  position: Float!
}
```

### `V2ScPageRow` (v2 pages)
```graphql
type V2ScPageRow {
  pageUrl: String!
  clicks: Float!
  impressions: Float!
  ctr: Float!
  position: Float!
}
```

### `V2ReportMeta` (on every v2 response)
```graphql
type V2ReportMeta {
  source: String!         # always "sc" for these
  reportKey: String!      # stable dataset key for the frontend
  accountLabel: String    # connected site/property label
  currencyCode: String
  timezone: String
  requestedRange: V2DateRange!
  # (more fields — introspect V2ReportMeta for the full shape)
}
```

### `V2PageInfo` (on `v2ScQueries` and `v2ScPages`)
```graphql
type V2PageInfo {
  page: Int!
  limit: Int!
  totalCount: Int!
  totalPages: Int!
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
}
```

### `ScTraffic` / `ScAnalytic` (v1)
v1 row types carry the same metrics plus their grouping dimensions inline:
- `ScTraffic`: `queried`, `urlId`, `countryIso3`, `deviceId`, plus `dated`/`year`/`quarter`/`month`/`week`/`day`, plus `clicks`/`impressions`/`ctr`/`position`.
- `ScAnalytic`: same minus `queried`/`urlId`/`countryIso3`/`deviceId` (the v1 aggregated form).

---

## Pagination

v2 (`v2ScQueries`, `v2ScPages`): `limit` + `page` on input → `pageInfo { totalCount totalPages hasNextPage }` on output.

v1 (`scTrafficsPaginated`): `limit` + `page` on input → `totalCount` / `totalPage` / `currentPage` on output.

`v2ScAnalytics` and `scAnalytics` are unpaginated (they return summary + date-grouped rows; expected result set is small).

## Notes

- Date freshness: Google typically lags 24–48 hours. A range that ends "today" may return less than expected.
- Empty `rows` is normal for new sites or low-traffic stores.
- The `token` header used to authenticate against reportgo is minted by the MCP transparently — you don't need to handle it. Decode the same token's `sub` claim only to read `spaceId`.
- Connection management (connect/disconnect/switch site) happens in the Risify Settings UI; if a user asks the agent to "connect GSC", direct them there.
