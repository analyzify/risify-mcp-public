# Flow: Google Search Console (GSC) Analytics

Analyze Google Search Console performance through the reportgo service — clicks, impressions, CTR, average position, and aggregated metrics over time, broken down by query / page / device / country. All read-only analytics; connection management stays in the Risify Settings page.

## Architecture

GSC analytics live on a separate service (reportgo) from the main Risify API. The MCP routes them automatically — pass `service: "gsc"` to `execute_graphql` and `introspect_schema` when querying GSC analytics. Use `service: "risify"` (the default) when checking GSC connection status or listing connected sites.

**Two key identifiers** every GSC analytics query needs:

- **`spaceId`** — multi-tenant isolation identifier on reportgo. Get it once per session by minting the space token and decoding its JWT `sub` claim (see step 2 below). The MCP doesn't expose this directly — fetch it yourself with one extra call.
- **`taskId`** — the GSC sync task on reportgo, returned as `reTaskId` from the `gscConnection` query on `service: "risify"`. Fetch it once and reuse for every analytics call.

## Capabilities

### 1. Check that GSC is connected and get `reTaskId` (always first)

Goes to the **Risify** API.

```graphql
query { gscConnection { id status email siteUrl reTaskId } }
```

- `status: "enabled"` means analytics queries will work.
- If `gscConnection` is `null` or any other status: tell the user GSC isn't connected and to set it up from Risify Settings → Search Console. Don't try analytics queries.
- Save `reTaskId` — every analytics query needs it as `taskId`.

### 2. Get the `spaceId` (once per session)

Mint the report space token, then decode the JWT's `sub` claim.

```graphql
mutation { reportGetSpaceToken }
```

Returns a JWT string like `eyJhbGciOi…`. Split on `.`, take the middle segment, base64url-decode it, parse JSON, read `sub` — that's the spaceId. Reuse it for every analytics call in this conversation.

Cache both `spaceId` and `taskId` in the conversation; don't re-fetch them per query.

### 3. Summary (single aggregated row across the range)

`service: "gsc"`. The reportgo schema calls this `scAnalytics`. With `groupByFields: []` and `groupByDate: false`, you get a single aggregated row over the whole range.

```graphql
query($input: ScAnalyticInput!) {
  scAnalytics(input: $input) {
    dated clicks impressions ctr position
  }
}
```

Variables (defaults: last 28 days, ending two days ago):
```json
{
  "input": {
    "default": {
      "spaceId": "<from-step-2>",
      "taskId": "<from-step-1>",
      "startDate": "2026-04-27",
      "endDate": "2026-05-24",
      "groupByFields": [],
      "groupByDate": false
    }
  }
}
```

Output template:
```
**Search Console — {startDate} to {endDate}**
Clicks: {clicks}  •  Impressions: {impressions}
CTR: {ctr}%       •  Avg position: {position}
```

Note: `ctr` comes back as a percentage already (e.g. `0.71` means 0.71%, not 71%). Do not multiply by 100.

### 4. Top queries by clicks

`service: "gsc"`. Group by `queried` and order by `clicks DESC`.

```graphql
query($input: ScTrafficInput!) {
  scTrafficsPaginated(input: $input) {
    totalCount currentPage totalPage
    nodes { queried clicks impressions ctr position }
  }
}
```

Variables:
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
    "limit": 50,
    "page": 1
  }
}
```

For "top by impressions" use `orderByFields: ["impressions DESC"]`. For "top by CTR" use `["ctr DESC"]`. For "best avg position" use `["position ASC"]` (lower is better).

### 5. Top pages

Same query, group by `url_id` instead:

```json
{ "input": { "default": { ..., "groupByFields": ["url_id"], "orderByFields": ["clicks DESC"] } } }
```

`urlId` in the response is the page URL.

### 6. By device / country

`groupByFields: ["device_id"]` or `["country_iso3"]`. Combine: `["queried", "device_id"]` for query × device breakdown. The response carries `deviceId` (1=desktop, 2=mobile, 3=tablet) and `countryIso3`.

### 7. Filter to specific queries / pages

Use the top-level filters on `ScTrafficInput` (these apply before aggregation):

| Filter | Effect |
|---|---|
| `queryExact: "saint bernard"` | Match a single query exactly |
| `queryContains: "boot"` | Substring match on the query |
| `queries: ["a", "b"]` + `queryOperator: AND \| OR` | Multi-query match |
| `pageExact: "/collections/x"` | Exact page URL |
| `pageContains: "/collections/"` | Substring match on page |
| `pageTypes: [...]` | Risify page-type filter |
| `countryIso3: "USA"` | ISO3 country |
| `deviceId: 2` | Raw device id (1 desktop, 2 mobile, 3 tablet) |
| `positionMin: 11, positionMax: 30` | Average position range, applied after aggregation |
| `brandFilter: BRANDED \| NON_BRANDED` + `brandRules: [...]` | Brand-vs-non-brand split |

Default branded/non-branded split: if you need it and `brandRules` aren't set in the account, infer the brand from `me.shopName` (Risify API) and pass it as a temporary rule.

### 8. CTR opportunities (high impressions, low CTR)

Pull top queries with a wide enough range to surface volume, then filter to rows with `impressions >= 500` and `ctr < 0.5` (i.e. under 0.5%) and `position <= 20`. Surface as "queries that show often but don't get clicked — title/meta refresh candidates".

### 9. Week-over-week position changes

1. Run top-queries query for current 7 days.
2. Run the same query for the prior 7 days.
3. Inner-join on `queried`, compute `position_delta = previous.position - current.position` (positive = improved). Sort descending.

### 10. Time series (trends)

Add `groupByDate: true` and a `dateArgs` entry with the granularity you want:

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

Granularities: `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`. The response carries `dated` plus the calendar components (`year`, `quarter`, `month`, `week`, `day`).

## Date conventions

- All dates are `YYYY-MM-DD` strings.
- Default range: last 28 days ending two days ago (Google has ~48h reporting lag).
- For "last month" use the previous calendar month.
- For "this week" / "last 7 days" use a rolling 7-day window ending two days ago.

## Output templates

Top-queries table:
```
| Query | Clicks | Impr. | CTR | Pos. |
|---|---:|---:|---:|---:|
| ... | ... | ... | ...% | ... |
```

Week-over-week movers table:
```
| Query | Pos (prev) | Pos (now) | Δ |
|---|---:|---:|---:|
```

## Error handling

| Situation | Response |
|-----------|----------|
| `gscConnection` is null or `status != "enabled"` | "Search Console isn't connected. Open Risify Settings → Search Console to connect it." Do not call analytics queries. |
| Token mint fails / 401 | "I can't reach Search Console right now. Try reconnecting it in Risify Settings." |
| Empty results | "No Search Console data for that range — Google takes about 48 hours to report new data, and very low-traffic stores may have nothing to show yet." |
| `spaceId` required error | The space token mint failed silently; re-fetch via `reportGetSpaceToken` and re-decode. |

## See also

- `gsc-operations.md` — full GraphQL queries with all input fields and response shapes.
- `account.md` — checking AI credits / plan if a feature is plan-gated.
