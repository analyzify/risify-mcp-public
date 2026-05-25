# GSC GraphQL Operations Reference

Read-only analytics from Google Search Console via the reportgo service. Pass `service: "gsc"` to `execute_graphql` and `introspect_schema` for every analytics operation in this file. Connection-status and token-mint operations use the default `service: "risify"`.

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

Returns a JWT. Decode the middle segment (base64url-decode → JSON-parse) and read the `sub` claim — that's the `spaceId` reportgo expects as `default.spaceId` for every analytics call. The JWT also has an `exp` claim (the MCP handles refresh transparently, but the value is useful if you decode manually).

Cache `spaceId` and `taskId` for the whole conversation; don't re-fetch them per query.

---

## Analytics (service: "gsc")

### `scAnalytics` — aggregated metrics for the range

```graphql
query ScAnalytics($input: ScAnalyticInput!) {
  scAnalytics(input: $input) {
    dated
    year
    quarter
    month
    week
    day
    clicks
    impressions
    ctr
    position
  }
}
```

Single aggregated row when `groupByFields: []` and `groupByDate: false`. Add `groupByDate: true` + `dateArgs` for time series (returns one row per period).

Variables — last-28-day summary:
```json
{
  "input": {
    "default": {
      "spaceId": "<from reportGetSpaceToken.sub>",
      "taskId": "<from gscConnection.reTaskId>",
      "startDate": "2026-04-27",
      "endDate": "2026-05-24",
      "groupByFields": [],
      "groupByDate": false
    }
  }
}
```

Variables — daily time series for 60 days:
```json
{
  "input": {
    "default": {
      "spaceId": "<...>",
      "taskId": "<...>",
      "startDate": "2026-03-25",
      "endDate": "2026-05-24",
      "groupByFields": [],
      "groupByDate": true,
      "dateArgs": [{ "groupBy": "DAY", "orderBy": "ASC" }]
    }
  }
}
```

### `scTraffics` — un-paginated rows grouped by dimension

```graphql
query ScTraffics($input: ScTrafficInput!) {
  scTraffics(input: $input) {
    dated
    queried
    urlId
    countryIso3
    deviceId
    clicks
    impressions
    ctr
    position
  }
}
```

Returns all matching rows in one call. Use `scTrafficsPaginated` instead when you need paging or a large result set.

### `scTrafficsPaginated` — paginated rows grouped by dimension

```graphql
query ScTrafficsPaginated($input: ScTrafficInput!) {
  scTrafficsPaginated(input: $input) {
    totalCount
    totalPage
    currentPage
    nodes {
      dated
      queried
      urlId
      countryIso3
      deviceId
      clicks
      impressions
      ctr
      position
    }
  }
}
```

Variables — top 50 queries by clicks, non-branded, mobile, last 28 days:
```json
{
  "input": {
    "default": {
      "spaceId": "<...>",
      "taskId": "<...>",
      "startDate": "2026-04-27",
      "endDate": "2026-05-24",
      "groupByFields": ["queried"],
      "orderByFields": ["clicks DESC"]
    },
    "deviceId": 2,
    "brandFilter": "NON_BRANDED",
    "brandRules": [{ "operator": "CONTAINS", "value": "saint bernard" }],
    "limit": 50,
    "page": 1
  }
}
```

Variables — top 50 pages under `/collections/` with position 11–30:
```json
{
  "input": {
    "default": {
      "spaceId": "<...>",
      "taskId": "<...>",
      "startDate": "2026-04-27",
      "endDate": "2026-05-24",
      "groupByFields": ["url_id"],
      "orderByFields": ["clicks DESC"]
    },
    "pageContains": "/collections/",
    "positionMin": 11,
    "positionMax": 30,
    "limit": 50,
    "page": 1
  }
}
```

### `scBrandRules` — read current branded-search rules

```graphql
query ScBrandRules($taskId: String!) {
  scBrandRules(taskId: $taskId) { operator value }
}
```

`taskId` is the same `reTaskId` from `gscConnection`.

### `scBrandRulesUpdate` — write rules (mutation; rarely needed via MCP)

```graphql
mutation ScBrandRulesUpdate($taskId: String!, $input: ScBrandRulesUpdateInput!) {
  scBrandRulesUpdate(taskId: $taskId, input: $input) { operator value }
}
```

Not exposed in the read-only flow above. If a user explicitly asks to redefine their brand rules, this mutation is available; confirm with the user before writing.

---

## `ScTrafficInput` reference

`default` (`StandardQueryInput!`) is required on every analytics call. Top-level fields are optional filters and pagination.

### `default: StandardQueryInput!`

| Field | Type | Notes |
|-------|------|-------|
| `spaceId` | `String!` | From `reportGetSpaceToken` JWT `sub` claim |
| `taskId` | `String` | From `gscConnection.reTaskId` |
| `refId` | `String` | Optional reference identifier |
| `startDate` | `String` | YYYY-MM-DD |
| `endDate` | `String` | YYYY-MM-DD |
| `groupByFields` | `[String!]` | One or more of: `queried`, `url_id`, `country_iso3`, `device_id` |
| `groupByDate` | `Boolean` | True for time series; pairs with `dateArgs` |
| `dateArgs` | `[DateArgs]` | `{ groupBy: Calendar, orderBy: SortDirection, filterFrom: Int, filterTo: Int }` |
| `orderByFields` | `[String!]` | e.g. `["clicks DESC"]`, `["position ASC"]` |

`Calendar` enum: `YEAR`, `MONTH`, `QUARTER`, `WEEK`, `DAY`.

### Top-level filters on `ScTrafficInput`

| Field | Type | Notes |
|-------|------|-------|
| `queryExact` | `String` | Exact query match (case-insensitive) |
| `queryContains` | `String` | Substring (case-insensitive) |
| `queries` | `[String!]` | Multi-term match |
| `queryOperator` | `ScQueryOperator` | `AND` / `OR` for `queries` |
| `pageExact` | `String` | Exact page URL |
| `pageContains` | `String` | Substring of page URL |
| `pageTypes` | `[PageType!]` | Risify page-type filter |
| `countryIso3` | `String` | ISO3 country code |
| `deviceId` | `Uint32` | 1=desktop, 2=mobile, 3=tablet |
| `positionMin` / `positionMax` | `Float` | Average position range (applied after aggregation) |
| `brandFilter` | `BrandFilter` | `BRANDED` / `NON_BRANDED` |
| `brandRules` | `[ScBrandRuleInput!]` | Inline rules `{ operator, value }` |
| `limit` | `Int` | Page size (paginated only) |
| `page` | `Int` | 1-indexed page number (paginated only) |
| `sort` | `[ScTrafficSort!]` | Type-safe sort (overrides `default.orderByFields`) |

### `ScAnalyticInput`

Same shape as `ScTrafficInput` but the response is the aggregated `[ScAnalytic!]!` shape (no `queried`/`urlId`/`countryIso3`/`deviceId` columns on the row itself — group via `default.groupByFields` if you want them).

---

## Response shapes

### `ScAnalytic`
| Field | Type | Notes |
|-------|------|-------|
| `dated` | `Date` | Period anchor (null when not grouping by date) |
| `year` / `quarter` / `month` / `week` / `day` | `Int!` | Calendar components |
| `clicks` | `Int64!` | |
| `impressions` | `Int64!` | |
| `ctr` | `Float!` | Percent value (e.g. 0.71 → 0.71%) |
| `position` | `Float!` | Avg position; lower is better |

### `ScTraffic`
| Field | Type | Notes |
|-------|------|-------|
| `dated` | `Date` | |
| `year`/`quarter`/`month`/`week`/`day` | Int components | |
| `queried` | `String!` | Search query |
| `urlId` | `String!` | Page URL |
| `countryIso3` | `String!` | Country |
| `deviceId` | `Uint32!` | 1=desktop, 2=mobile, 3=tablet |
| `clicks` | `Int64!` | |
| `impressions` | `Int64!` | |
| `ctr` | `Float!` | Percent value |
| `position` | `Float!` | |

### `ScTrafficsPaginated`
| Field | Type | Notes |
|-------|------|-------|
| `totalCount` | `Int!` | |
| `totalPage` | `Int!` | |
| `currentPage` | `Int!` | |
| `nodes` | `[ScTraffic!]!` | |

---

## Pagination

`scTrafficsPaginated` uses offset pagination — `limit`+`page` on input, `totalCount`/`totalPage`/`currentPage` on output. The reportgo schema does not currently expose a Relay-style cursor connection for SC.

## Sorting

Use `default.orderByFields: ["<field> DESC|ASC"]` for legacy string-based sort, or the typed `sort: [{ field: ScTrafficSortField, direction: SortDirection }]` argument when typed-codegen ergonomics matter. When both are present, `sort` takes precedence.

## Notes

- Date freshness: Google typically lags 24–48 hours. A range that ends "today" may return less than expected.
- Empty result is normal for new sites or low-traffic stores.
- The `token` header used to authenticate against reportgo is minted by the MCP transparently — you don't need to handle it directly. Decode the same token's `sub` claim only to read `spaceId`.
- Mutations beyond `scBrandRulesUpdate` are not exposed here. Connection management (connect/disconnect/switch site) happens in the Risify Settings UI; if a user asks the agent to "connect GSC", direct them there.
