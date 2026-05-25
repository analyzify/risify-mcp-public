# Flow: Google Search Console (GSC) Analytics

Analyze Google Search Console performance through the reportgo service — clicks, impressions, CTR, and average position, by overall summary, query, or page, with optional period-over-period comparison. All read-only analytics; connection management stays in the Risify Settings page.

## Architecture

GSC analytics live on a separate service (reportgo) from the main Risify API. The MCP routes them automatically — pass `service: "gsc"` to `execute_graphql` and `introspect_schema` when querying GSC analytics. Use `service: "risify"` (the default) when checking GSC connection status.

There are **two tiers** of GSC operations on reportgo:

| Tier | Queries | When to use |
|---|---|---|
| **v2 (primary, what to use)** | `v2ScAnalytics`, `v2ScQueries`, `v2ScPages` | Almost every agent task. Each returns `{ summary, rows, meta, comparison?, pageInfo? }` — pre-shaped, less knowledge required, supports period-over-period. |
| v1 (advanced) | `scTraffics`, `scTrafficsPaginated`, `scAnalytics` | Only when you need custom `groupByFields` combinations (e.g. query × device, page × country) or filter dimensions the v2 surface doesn't expose. |

**Default to v2** unless a recipe explicitly calls for v1.

**Two key identifiers** every GSC analytics query needs:

- **`spaceId`** — multi-tenant isolation identifier on reportgo. Get it once per session: mint `reportGetSpaceToken` (on `service: "risify"`), then base64url-decode the JWT's middle segment and read the `sub` claim. **It is NOT the Risify user id.**
- **`taskId`** — the GSC sync task on reportgo, returned as `reTaskId` from the `gscConnection` query on `service: "risify"`.

Cache both for the conversation; don't re-fetch them per query.

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

```graphql
mutation { reportGetSpaceToken }
```

Returns a JWT like `eyJhbGciOi…`. Split on `.`, take segment 2 (the payload), base64url-decode it, parse JSON, read `sub`. That string is the `spaceId`. Save it.

### 3. Summary (single row across the range)

`service: "gsc"`. `v2ScAnalytics` with no `comparison`.

```graphql
query($input: V2ScAnalyticsInput!) {
  v2ScAnalytics(input: $input) {
    summary { clicks impressions ctr position }
    meta { source reportKey timezone }
  }
}
```

Variables — default last 28 days, ending two days ago:

```json
{ "input": {
  "default": {
    "spaceId": "<from-step-2>",
    "taskId": "<from-step-1>",
    "startDate": "2026-04-27",
    "endDate": "2026-05-24"
  }
}}
```

Output template:

```
**Search Console — {startDate} to {endDate}**
Clicks: {clicks}  •  Impressions: {impressions}
CTR: {ctr}%       •  Avg position: {position}
```

`ctr` comes back as a percent value already (`0.71` means 0.71%, not 71%) — do not multiply by 100.

### 4. Top queries

`service: "gsc"`. `v2ScQueries` returns rows with `query`, `clicks`, `impressions`, `ctr`, `position` — no manual aggregation.

```graphql
query($input: V2ScQueriesInput!) {
  v2ScQueries(input: $input) {
    summary { clicks impressions ctr position }
    rows { query clicks impressions ctr position }
    pageInfo { page limit totalCount totalPages hasNextPage }
  }
}
```

Variables — top by impressions:

```json
{ "input": {
  "default": {
    "spaceId": "<...>",
    "taskId": "<...>",
    "startDate": "2026-04-27",
    "endDate": "2026-05-24",
    "orderByFields": ["-impressions"],
    "limit": 50,
    "page": 1
  }
}}
```

`orderByFields` uses a `-` prefix for descending. Valid keys: `clicks`, `impressions`, `ctr`, `position`. Use `position` (no `-`) for "best position" (lower = better).

### 5. Top pages

`service: "gsc"`. `v2ScPages` returns rows with `pageUrl`, `clicks`, `impressions`, `ctr`, `position`.

```graphql
query($input: V2ScPagesInput!) {
  v2ScPages(input: $input) {
    summary { clicks impressions ctr position }
    rows { pageUrl clicks impressions ctr position }
    pageInfo { page limit totalCount hasNextPage }
  }
}
```

Variables: same shape as queries, with `orderByFields: ["-clicks"]` for "top by clicks".

### 6. Period-over-period comparison

Add a `comparison` block alongside `default` — same shape. The v2 response carries both periods.

```graphql
query($input: V2ScPagesInput!) {
  v2ScPages(input: $input) {
    summary { clicks impressions ctr position }
    rows { pageUrl clicks impressions ctr position }
    comparison { summary { clicks impressions ctr position } rows { pageUrl clicks impressions ctr position } }
  }
}
```

```json
{ "input": {
  "default":    { "spaceId": "<...>", "taskId": "<...>", "startDate": "2026-04-27", "endDate": "2026-05-24", "limit": 50, "page": 1, "orderByFields": ["-clicks"] },
  "comparison": { "spaceId": "<...>", "taskId": "<...>", "startDate": "2026-03-30", "endDate": "2026-04-26", "limit": 50, "page": 1, "orderByFields": ["-clicks"] }
}}
```

Then inner-join on `pageUrl` (or `query`) to compute deltas.

### 7. CTR opportunities (high impressions, low CTR)

Run `v2ScPages` with `orderByFields: ["-impressions"]`, then filter rows: `impressions >= 500` AND `ctr < 0.5` AND `position <= 20`. Surface as "pages shown often but rarely clicked — title/meta refresh candidates". This is the read half of Recipe 19 in `recipes.md`.

### 8. Filter / advanced cases → v1

The v2 inputs (`V2ScPagesInput`, `V2ScQueriesInput`, `V2ScAnalyticsInput`) take only `default` + optional `comparison`. They do not expose query/page substring filters, country/device filters, or `groupByFields` combinations.

If you need:

- `queryContains` / `pageContains` substring filter
- `countryIso3` / `deviceId` slicing
- Custom `groupByFields` (e.g. query × device)
- Branded/non-branded splits (`brandFilter` + `brandRules`)
- Time-series breakdown by day/week (`groupByDate` + `dateArgs`)

→ Drop down to v1 `scTraffics` / `scTrafficsPaginated` / `scAnalytics`. See `gsc-operations.md` "v1 advanced" section for the input shape (`ScTrafficInput` wraps `StandardQueryInput` with the same `spaceId` / `taskId` plus all the extra filters).

## Date conventions

- All dates are `YYYY-MM-DD` strings.
- Default range: last 28 days ending two days ago (Google has ~48h reporting lag).
- "Last month" = previous calendar month.
- "This week" / "last 7 days" = rolling 7-day window ending two days ago.

## Output templates

Top-queries table:
```
| Query | Clicks | Impr. | CTR | Pos. |
|---|---:|---:|---:|---:|
| ... | ... | ... | ...% | ... |
```

Top-pages table (same shape, replace Query with Page).

Week-over-week movers (after comparison join):
```
| Item | Now (clicks) | Prev (clicks) | Δ |
|---|---:|---:|---:|
```

## Error handling

| Situation | Response |
|-----------|----------|
| `gscConnection` is null or `status != "enabled"` | "Search Console isn't connected. Open Risify Settings → Search Console to connect it." Do not call analytics queries. |
| `Cannot query field "X"` on a v2 type | You guessed a field name. The summary fields are `clicks`, `impressions`, `ctr`, `position` (flat — no `total*` or `average*` prefix). Row types are `V2ScPageRow` / `V2ScQueryRow` / `V2ScAnalyticsRow`; introspect the matching `*Response` type to see what's available. |
| Token mint fails / 401 | "I can't reach Search Console right now. Try reconnecting it in Risify Settings." |
| Empty `rows` array | "No Search Console data for that range — Google takes about 48 hours to report new data, and very low-traffic stores may have nothing to show yet." |

## See also

- `gsc-operations.md` — full GraphQL queries with all input fields and response shapes for both v2 and v1.
- `recipes.md` Category 9 — cross-flow recipes joining GSC reads with Risify write flows (Recipe 19 in particular uses `v2ScPages`).
- `account.md` — checking AI credits / plan if a feature is plan-gated.
