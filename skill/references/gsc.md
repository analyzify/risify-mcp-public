# Flow: Google Search Console (GSC) Analytics

Analyze Google Search Console performance — search queries, page-level metrics, clicks, impressions, CTR, and average position over time. All read-only analytics; connection management stays in the Risify Settings page.

## Architecture

GSC analytics live on a separate service from the main Risify API. The MCP routes them automatically — pass `service: "gsc"` to `execute_graphql` and `introspect_schema` when querying GSC analytics. Use `service: "risify"` (the default) when checking GSC connection status or listing connected sites.

## Capabilities

### 1. Check that GSC is connected (before any analytics call)

Always check the connection first. This call goes to the **Risify** API, not the GSC service.

```graphql
query { gscConnection { id status email siteUrl connectedAt } }
```

- `status` of `connected` / `active` means analytics queries will work.
- If `gscConnection` returns `null` or any other status: tell the user GSC isn't connected and to set it up from the Risify Settings page (Search Console section). Don't try analytics queries until they reconnect.

### 2. Get a summary (totals + trends)

`service: "gsc"`.

```graphql
query Summary($filter: GscFilter!) {
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

Variables (defaults: last 28 days):
```json
{ "filter": { "StartDate": "YYYY-MM-DD", "EndDate": "YYYY-MM-DD" } }
```

Output template:
```
**Search Console — {StartDate} to {EndDate}**
Clicks: {TotalClicks}  •  Impressions: {TotalImpressions}
CTR: {AvgCtr*100}%      •  Avg position: {AvgPosition}
```

### 3. Top queries by clicks/impressions

`service: "gsc"`.

```graphql
query TopQueries($filter: GscFilter!, $first: Int, $after: String) {
  gscQueries(filter: $filter, first: $first, after: $after) {
    nodes { query clicks impressions ctr position }
    pageInfo { hasNextPage endCursor }
    totalCount
  }
}
```

Defaults: `first: 20`, last 28 days. Present as a Markdown table sorted by the metric the user asked for (clicks unless they say "impressions" / "rank"). If asked for "top movers", run the query twice (current period + previous period of equal length) and join on `query`.

### 4. Top pages

`service: "gsc"`.

```graphql
query TopPages($filter: GscFilter!, $first: Int, $after: String) {
  gscPages(filter: $filter, first: $first, after: $after) {
    nodes { page clicks impressions ctr position }
    pageInfo { hasNextPage endCursor }
    totalCount
  }
}
```

### 5. CTR opportunities (high impressions, low CTR)

Use `gscQueries` with default range, then in code/Markdown filter `nodes` to those with `impressions >= 500` and `ctr < 0.02` and `position <= 20`. Surface as "queries that show often but don't get clicked — title/meta refresh candidates".

### 6. Position changes (week-over-week)

1. Call `gscQueries` once with last 7 days.
2. Call `gscQueries` once with the 7 days before that.
3. Inner-join on `query`, compute `position_delta = previous.position - current.position` (positive = improved). Sort descending.

## Filters available on `GscFilter`

| Field | Type | Notes |
|-------|------|-------|
| `StartDate` | String! | YYYY-MM-DD |
| `EndDate` | String! | YYYY-MM-DD |
| `Device` | String | `DESKTOP`, `MOBILE`, `TABLET` |
| `Country` | String | ISO-3 country code (`USA`, `GBR`, etc.) |
| `QueryContains` | String | Case-insensitive substring |
| `QueryNotContains` | String | Substring to exclude (use for "non-branded" filter) |
| `QueryPositionMin` / `QueryPositionMax` | Int | Position range bound |
| `PageContains` | String | Substring of URL |

When the user says "branded" without specifying, infer the brand from `me.shopName` (Risify API). For "non-branded" pass that token as `QueryNotContains`.

## Date conventions

- Always pass `YYYY-MM-DD` strings.
- Default range: last 28 days ending two days ago (GSC has ~48h reporting lag).
- For "last month" use the previous calendar month.
- For "this week" / "last 7 days" use a rolling 7-day window.

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
| `gscConnection` is null or `status != connected` | "Search Console isn't connected. Open Risify Settings → Search Console to connect it." Do not call analytics queries. |
| Token mint fails (auth) | "I can't reach Search Console right now. Try reconnecting it in Risify Settings." |
| Empty results | "No Search Console data for that range — Google takes about 48 hours to report new data, and very low-traffic stores may have nothing to show yet." |
| Subscription required | Some accounts gate GSC behind a paid plan. If the API surfaces a plan error, show plans (see `account.md`). |

## See also

- `gsc-operations.md` — full GraphQL queries with all fields.
- `account.md` — checking AI credits / plan if a feature is plan-gated.
