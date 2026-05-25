# Keyword Tracking GraphQL Operations Reference

All operations use `execute_graphql` with **`service: "keyword"`**. Read-only — this release intentionally does not expose mutations.

---

## Catalogues

### List catalogues (offset pagination)
```graphql
query Catalogues($input: CataloguesInput) {
  catalogues(input: $input) {
    totalPages
    totalCount
    currentPage
    catalogues {
      id
      userId
      name
      device
      countryId
      languageId
      createdAt
      updatedAt
      edges {
        domain { id host }
        country { id name isoCode }
        language { id name isoCode }
        catalogueTags { id name }
      }
    }
  }
}
```

Variables:
```json
{ "input": { "limit": 50, "page": 1 } }
```

### List catalogues (cursor pagination)
```graphql
query CataloguesConnection($args: ConnectionArgs) {
  cataloguesConnection(args: $args) {
    nodes { id name device edges { domain { host } } }
    pageInfo { hasNextPage endCursor }
  }
}
```

### Get a single catalogue with snapshots
```graphql
query CatalogueDetail($input: CatalogueDetailInput!) {
  catalogueDetail(input: $input) {
    id name device createdAt updatedAt
    edges {
      domain { host }
      country { name isoCode }
      language { name isoCode }
      catalogueTags { id name }
      cataloguePositionSnapshots {
        id dated averagePosition top3 top10 top20 top30 top50 top100
      }
    }
  }
}
```

Variables:
```json
{
  "input": {
    "id": "<catalogue-id>",
    "startDate": "2026-04-25",
    "endDate": "2026-05-25"
  }
}
```

---

## Catalogue Items (tracked keywords)

### List items
```graphql
query CatalogueItems($input: CatalogueItemInput!) {
  catalogueItems(input: $input) {
    totalPages
    totalCount
    currentPage
    catalogueItems {
      id
      catalogueId
      keywordId
      tags
      lastUpdated
      frequency
      url
      urlMapping
      position
      day7
      day30
      status
      edges {
        keyword {
          name
          searchVolume
          cpc
          competition
          competitionIndex
          searchIntent
          keywordDifficulty
          competitionLevel
          monthlySearches { year month searchVolume }
          searchVolumeTrend { monthly quarterly yearly }
        }
        catalogueItemPositionSnapshots {
          dated position url isFeaturedSnippet
        }
      }
    }
  }
}
```

Variables:
```json
{
  "input": {
    "catalogueId": "<catalogue-id>",
    "startDate": "2026-04-25",
    "endDate": "2026-05-25",
    "limit": 50,
    "page": 1,
    "keywordName": "optional-filter"
  }
}
```

---

## Position queries

### Latest distribution
```graphql
query PositionDistribution($input: CatalogueIdGenericInput!) {
  positionDistribution(input: $input) {
    id dated averagePosition top3 top10 top20 top30 top50 top100
  }
}
```

### Position summary
```graphql
query PositionGeneralInfo($input: CatalogueIdGenericInput!) {
  positionGeneralInfo(input: $input) {
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

### Trend over a range
```graphql
query Trend($input: CataloguePositionTrendInput!) {
  cataloguePositionTrend(input: $input) {
    id dated averagePosition top3 top10 top20 top30 top50 top100
  }
}
```

### Single-keyword history
```graphql
query History($input: PositionHistoryInput!) {
  positionHistory(input: $input) {
    id dated position url isFeaturedSnippet
  }
}
```

### Biggest gainers / losers (this week)
```graphql
query Movers($catalogueId: String!) {
  positionBiggestGainers(input: { catalogueId: $catalogueId }) {
    id position day7 day30 tags url
    edges { keyword { name searchVolume } }
  }
  positionBiggestLosers(input: { catalogueId: $catalogueId }) {
    id position day7 day30 tags url
    edges { keyword { name searchVolume } }
  }
}
```

### Position changes over a range
```graphql
query Changes($input: PositionChangesInput!) {
  positionChanges(input: $input) {
    id position day7 day30
    edges { keyword { name } }
  }
}
```

Variables:
```json
{
  "input": {
    "catalogueId": "<id>",
    "startDate": "2026-04-25",
    "endDate": "2026-05-25"
  }
}
```

### Keyword rankings (alternate listing)
```graphql
query Rankings($input: KeywordRankingsInput!) {
  positionKeywordRankings(input: $input) {
    totalCount totalPages currentPage
    catalogueItems {
      id position day7 day30 url tags status
      edges { keyword { name searchVolume keywordDifficulty } }
    }
  }
}
```

### Cursor-paginated variants
```graphql
positionChangesConnection(args: ConnectionArgs): CatalogueItemConnection!
positionBiggestGainersConnection(args: ConnectionArgs): CatalogueItemConnection!
positionBiggestLosersConnection(args: ConnectionArgs): CatalogueItemConnection!
positionKeywordRankingsConnection(args: ConnectionArgs): CatalogueItemConnection!
```

`args.query` carries the scope (`catalogueId=...`, optional date hints, etc.). Prefer the offset variants for now unless paging deep.

---

## Keyword Discovery

### List discoveries
```graphql
query Discoveries($input: KeywordDiscoveriesInput) {
  keywordDiscoveries(input: $input) {
    totalCount totalPages currentPage
    nodes {
      id createdAt updatedAt dated year month day
      type title keywordId
      edges {
        keyword {
          name searchVolume cpc keywordDifficulty competitionLevel
        }
      }
    }
  }
}
```

Variables:
```json
{
  "input": {
    "catalogueId": "<catalogue-id>",
    "keywordName": "optional-filter",
    "limit": 50,
    "page": 1
  }
}
```

### Discovery summary card
```graphql
query DiscoveryInfo($catalogueId: String!) {
  keywordDiscoveryGeneralInfo(catalogueId: $catalogueId) {
    newTermsFoundTodayCount
    newTermsFoundThisWeekCount
    allTimeTermsCount
    topSource
  }
}
```

---

## Type reference

### CatalogueItem (key fields)
| Field | Type | Notes |
|-------|------|-------|
| `id` | `String!` | |
| `catalogueId` | `String!` | |
| `keywordId` | `String!` | |
| `position` | `Int` | Current best rank; null = not in top 100 |
| `day7` | `Int` | Rank 7 days ago |
| `day30` | `Int` | Rank 30 days ago |
| `frequency` | `String!` | `daily`, `weekly`, `monthly` |
| `tags` | `[String!]` | User-applied labels |
| `url` | `String` | Best-ranking URL detected |
| `urlMapping` | `String` | User-overridden URL to track |
| `status` | `String` | `active` / `inactive` |
| `edges.keyword` | `Keyword` | Shared keyword metadata + search volume |
| `edges.catalogueItemPositionSnapshots` | `[CatalogueItemPositionSnapshot!]` | Daily history |

### Keyword (key fields)
| Field | Type | Notes |
|-------|------|-------|
| `name` | `String!` | The keyword text |
| `searchVolume` | `Int` | Monthly searches |
| `cpc` | `Float` | Cost per click |
| `competition` | `String` | `LOW`/`MEDIUM`/`HIGH` |
| `competitionIndex` | `Int` | 0–100 |
| `keywordDifficulty` | `Int` | 0–100 |
| `searchIntent` | `String` | informational / navigational / commercial / transactional |
| `monthlySearches` | `[KeywordMonthlySearch!]!` | Per-month volume history |
| `searchVolumeTrend` | `SearchVolumeTrend` | `{ monthly, quarterly, yearly }` percent deltas |

### CataloguePositionSnapshot
| Field | Type | Notes |
|-------|------|-------|
| `dated` | `String!` | YYYY-MM-DD |
| `averagePosition` | `Float` | Lower is better |
| `top3` / `top10` / `top20` / `top30` / `top50` / `top100` | `Int` | Count of tracked keywords in that bucket |

### CatalogueItemPositionSnapshot
| Field | Type | Notes |
|-------|------|-------|
| `dated` | `String!` | YYYY-MM-DD |
| `position` | `Int!` | |
| `url` | `String` | URL that ranked on that day |
| `isFeaturedSnippet` | `Boolean` | |

### KeywordDiscovery
| Field | Type | Notes |
|-------|------|-------|
| `dated` | `String` | YYYY-MM-DD when found |
| `type` | `String` | Source category |
| `title` | `String` | SERP title at time of discovery |
| `edges.keyword` | `Keyword!` | Full keyword info |

## Pagination

Two patterns are available:

- **Offset** — `input: { limit, page }` → response has `totalCount`, `totalPages`, `currentPage`. Use this by default; it's what most of these endpoints support.
- **Cursor** — `args: ConnectionArgs` with `first`, `after`, etc. Use for `cataloguesConnection` and the `*Connection` variants under position queries.

## Date conventions

- All date inputs are `YYYY-MM-DD` strings.
- Default range when the user doesn't specify: last 30 days.
- The keyword service does not have GSC's reporting lag — ranks update on each scheduled poll per the keyword's `frequency`.

## Mutations (intentionally not exposed in this release)

The keyword service supports writes (`createCatalogue`, `createCatalogueItems`, `updateCatalogueItemTags`, `updateCatalogueItemStatus`, `deleteCatalogueItem`, `deleteCatalogue`). They are **deliberately not documented for MCP use** in v1 — if a user asks to make changes, point them to the Risify Keyword Tracking page in the app.
