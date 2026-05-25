# Flow: Keyword Tracking & Discovery

Analyze tracked keyword rankings, position history, top movers, and newly discovered keywords. Read-only in this release — add/remove keywords still happens in the Risify Keyword Tracking page.

## Architecture

Keyword data lives on a separate service. Always pass `service: "keyword"` to `execute_graphql` and `introspect_schema` for the operations in this flow.

**Vocabulary**:

- **Catalogue** — a tracking scope: one domain + country + language + device. A user can have several (e.g., US/desktop vs UK/mobile).
- **Catalogue item** — a keyword the user has chosen to track inside a catalogue. Has current position, day-7 position, day-30 position, frequency, tags.
- **Keyword discovery** — keywords the system found ranking the user's domain that aren't explicitly tracked yet. Useful for "what should I be tracking?"
- **Position snapshot** — a dated rollup at the catalogue level: avg position + counts in top 3 / 10 / 20 / 30 / 50 / 100.

## Capabilities

### 1. List the user's catalogues

```graphql
query { catalogues(input: { limit: 50, page: 1 }) {
  totalCount totalPages currentPage
  catalogues {
    id name device createdAt
    edges { domain { host } country { name } language { name } }
  }
} }
```

Output template:
```
You have {totalCount} catalogue(s):
- **{name}** — {domain.host} • {country.name} • {device}
  (id: {id})
```

If `totalCount` is 0: tell the user they don't have any keyword catalogues yet — they can create one in the Risify Keyword Tracking page.

### 2. Show catalogue detail (with position snapshots)

```graphql
query Detail($id: String!, $startDate: String!, $endDate: String!) {
  catalogueDetail(input: { id: $id, startDate: $startDate, endDate: $endDate }) {
    id name device
    edges {
      domain { host }
      cataloguePositionSnapshots {
        dated averagePosition top3 top10 top20 top30 top50 top100
      }
    }
  }
}
```

Default range: last 30 days.

### 3. List tracked keywords in a catalogue

```graphql
query Items($input: CatalogueItemInput!) {
  catalogueItems(input: $input) {
    totalCount totalPages currentPage
    catalogueItems {
      id position day7 day30 url frequency status tags
      edges { keyword { name searchVolume cpc keywordDifficulty } }
    }
  }
}
```

Variables:
```json
{
  "input": {
    "catalogueId": "<id>",
    "startDate": "2026-04-25",
    "endDate": "2026-05-25",
    "limit": 50,
    "page": 1
  }
}
```

Present as a table sorted by `position` ascending. Highlight: items where `position == null` are "not in top 100".

### 4. Position summary

```graphql
query Summary($catalogueId: String!) {
  positionGeneralInfo(input: { catalogueId: $catalogueId }) {
    totalKeywordsTrackedCount
    totalKeywordsTrackedCountThisMonth
    averagePosition
    averagePositionLastWeek
    keywordsInTopTenCount
    keywordsInTopTenCountLastWeek
    serpFeaturesCount
    serpFeaturesCountLastWeek
  }
}
```

Output template:
```
**{catalogue.name}** — {totalKeywordsTrackedCount} keywords tracked
Avg position: {averagePosition} (was {averagePositionLastWeek} last week)
In top 10: {keywordsInTopTenCount} (was {keywordsInTopTenCountLastWeek})
SERP features: {serpFeaturesCount}
```

### 5. Biggest gainers / losers (this week)

```graphql
query Gainers($catalogueId: String!) {
  positionBiggestGainers(input: { catalogueId: $catalogueId }) {
    id position day7 day30
    edges { keyword { name } }
  }
  positionBiggestLosers(input: { catalogueId: $catalogueId }) {
    id position day7 day30
    edges { keyword { name } }
  }
}
```

Use both lists. "Movement" = `day7 - position` (positive = improved; negative = dropped). Surface as two side-by-side tables.

### 6. Position history (single keyword over time)

```graphql
query History($input: PositionHistoryInput!) {
  positionHistory(input: $input) {
    dated position url isFeaturedSnippet
  }
}
```

Variables:
```json
{
  "input": {
    "catalogueItemId": "<item-id>",
    "startDate": "2026-04-25",
    "endDate": "2026-05-25"
  }
}
```

Present as a chronological list or a small line summary. Note any `isFeaturedSnippet: true` rows — those are wins to highlight.

### 7. Distribution snapshot (latest)

```graphql
query Dist($catalogueId: String!) {
  positionDistribution(input: { catalogueId: $catalogueId }) {
    dated averagePosition top3 top10 top20 top30 top50 top100
  }
}
```

Output template:
```
**Ranking distribution — {dated}**
Top 3: {top3} • Top 10: {top10} • Top 20: {top20}
Top 30: {top30} • Top 50: {top50} • Top 100: {top100}
Avg position: {averagePosition}
```

### 8. Trend over time (chart-friendly)

```graphql
query Trend($input: CataloguePositionTrendInput!) {
  cataloguePositionTrend(input: $input) {
    dated averagePosition top3 top10 top20 top30 top50 top100
  }
}
```

Plot or table the daily series.

### 9. Newly discovered keywords

```graphql
query Discoveries($input: KeywordDiscoveriesInput) {
  keywordDiscoveries(input: $input) {
    totalCount totalPages currentPage
    nodes {
      id dated type title
      edges { keyword { name searchVolume cpc keywordDifficulty } }
    }
  }
}
```

Variables:
```json
{ "input": { "catalogueId": "<id>", "limit": 50, "page": 1 } }
```

And the summary card:
```graphql
query DiscoverInfo($catalogueId: String!) {
  keywordDiscoveryGeneralInfo(catalogueId: $catalogueId) {
    newTermsFoundTodayCount
    newTermsFoundThisWeekCount
    allTimeTermsCount
    topSource
  }
}
```

## Output templates

Tracked-keyword table:
```
| Keyword | Pos | 7d | 30d | Vol | Diff | URL |
|---|---:|---:|---:|---:|---:|---|
| ... | 3 | 5 | 8 | 1,200 | 42 | /collections/x |
```

Movers table (two columns side-by-side):
```
| Gainers | Pos now | Pos 7d | Δ |  | Losers | Pos now | Pos 7d | Δ |
```

## Frequency values

Frequencies are strings — common values from the Risify UI: `daily`, `weekly`, `monthly`. Show them as-is.

## Read-only note

This release intentionally exposes **only reads** for keyword tracking. If the user asks to:
- "Add keyword X to tracking" / "stop tracking Y" / "tag keywords" / "create a new catalogue"

… tell them: "I can show you everything about your tracked keywords, but adding or removing them needs to happen in the Risify Keyword Tracking page." Don't try to call write operations.

## Error handling

| Situation | Response |
|-----------|----------|
| Token mint fails / subscription required | "Keyword Tracking needs an active Risify plan. Open Risify and check your subscription." |
| `catalogues` returns 0 | "You haven't set up any keyword catalogues yet — head to the Keyword Tracking page in Risify to create one." |
| `catalogueDetail` not found | "I couldn't find that catalogue — it may have been deleted. Try listing your catalogues again." |
| Empty `keywordDiscoveries` | "No new discoveries yet — discoveries surface as the system observes new ranking keywords for your domain." |

## See also

- `keywords-operations.md` — full GraphQL reads with all fields.
- `account.md` — plan/subscription checks if a feature is plan-gated.
