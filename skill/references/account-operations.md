# Account GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool directly against the Risify API.

---

## Queries

### Get Account Info (me)
```graphql
query {
  me {
    id
    createdAt
    firstName
    lastName
    fullName
    email
    shopUrl
    shopName
    shopSlug
    domain
    status
    purchaseDate
    currencyCode
    isAppSubscriptionPlanActive
    appEmbedStatus
    subTrialDays
    subCanTrial
    supportPeriodEndDate
    appSubscriptionCharge {
      id
      createdAt
      updatedAt
      name
      price
      appliedDiscountAmount
      status
      chargeType
      chargeId
      subscriptionPeriodEnd
      test
      subTrialApplied
      subTrialEndsAt
      discountCycles
      edges {
        plan {
          id
          name
          price
          chargeType
          planType
          headline
          description
          tags { key value }
          discountAmount
          shopifySubscriptionInterval
        }
      }
    }
  }
}
```

### Get AI Credit Info
```graphql
query {
  aiCreditInfo {
    limit
    usage
    resetAt
  }
}
```

### List Contacts
```graphql
query {
  contactList(page: 1, limit: 10) {
    nodes {
      id
      name
      email
      createdAt
      updatedAt
      edges {
        storeRole {
          id
          name
          displayName
        }
      }
    }
    totalCount
    totalPage
    currentPage
  }
}
```

### Get Single Contact
```graphql
query {
  contactGet(id: "<contact-id>") {
    id
    name
    email
    createdAt
    edges {
      storeRole {
        id
        name
        displayName
      }
    }
  }
}
```

### List Store Roles
```graphql
query {
  storeRoleList {
    id
    name
    displayName
  }
}
```

### List Charges (Billing History)
```graphql
query {
  chargeList(page: 1, limit: 10) {
    nodes {
      id
      createdAt
      updatedAt
      name
      price
      appliedDiscountAmount
      status
      chargeType
      chargeTypeInternal
      subscriptionPeriodEnd
      test
      subTrialApplied
      subTrialEndsAt
      discountCycles
      edges {
        plan {
          id
          name
          price
          planType
        }
      }
    }
    totalCount
    totalPage
    currentPage
  }
}
```

### List Plans
```graphql
query {
  planList(planType: PRODUCT) {
    nodes {
      id
      name
      price
      chargeType
      planType
      serviceId
      headline
      icon
      description
      tags { key value }
      addonTypeSlug
      sortOrder
      discountAmount
      shopifySubscriptionInterval
      edges {
        planCredits {
          id
          planId
          status
          amount
          expiresAt
        }
        planDiscounts {
          id
          planId
          status
          amount
          expiresAt
        }
      }
    }
    totalCount
    totalPage
    currentPage
  }
}
```

Plan type enum values: `PRODUCT`, `ADDON`, `SERVICE`

---

## Mutations

### Create Contact
```graphql
mutation {
  contactCreate(input: {
    name: "John Doe"
    email: "john@example.com"
    storeRoleId: "<role-id-from-storeRoleList>"
  }) {
    id
    name
    email
    edges {
      storeRole {
        id
        displayName
      }
    }
  }
}
```

### Update Contact
```graphql
mutation {
  contactUpdate(id: "<contact-id>", input: {
    name: "Updated Name"
    email: "updated@example.com"
    storeRoleId: "<role-id>"
  }) {
    id
    name
    email
    edges {
      storeRole {
        displayName
      }
    }
  }
}
```

### Delete Contact
```graphql
mutation {
  contactDelete(id: "<contact-id>") {
    id
    name
    email
  }
}
```

### Buy Plan
```graphql
mutation {
  planBuy(planId: "<plan-id>") {
    returnUrl
  }
}
```

Returns a Shopify confirmation URL the user must visit to complete the purchase.

### Verify Charge
```graphql
mutation {
  chargeVerify(chargeId: 12345) {
    id
    name
    price
    status
    subscriptionPeriodEnd
  }
}
```

`chargeId` is a Shopify numeric charge ID (Uint64).

### Claim Plan Credit
```graphql
mutation {
  planCreditClaim(planCreditId: "<plan-credit-id>") {
    id
    name
    status
  }
}
```

### Cancel Subscription
```graphql
mutation {
  appSubscriptionCancel(id: "<risify-charge-id>") {
    id
    name
    status
    subscriptionPeriodEnd
  }
}
```

The `id` is the Risify internal charge ID (from `me.appSubscriptionCharge.id`), NOT the Shopify chargeId.

---

## Type Reference

### MeInfo (key fields)
| Field | Type | Description |
|-------|------|-------------|
| `id` | String! | User ID |
| `email` | String! | Account email |
| `shopUrl` | String! | Store URL |
| `shopName` | String | Store display name |
| `domain` | String! | Primary domain |
| `purchaseDate` | Time | When they first subscribed |
| `isAppSubscriptionPlanActive` | Boolean! | Whether subscription is active |
| `appSubscriptionCharge` | Charge | Current active charge details |
| `appEmbedStatus` | Boolean | Whether app embed is enabled in theme |
| `subTrialDays` | Int | Trial days available |
| `subCanTrial` | Boolean | Whether user is eligible for trial |

### Charge
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Risify charge ID |
| `chargeId` | Uint64 | Shopify charge ID |
| `name` | String | Plan name |
| `price` | Float | Plan price |
| `appliedDiscountAmount` | Float | Discount applied |
| `status` | String | active, cancelled, frozen, etc. |
| `subscriptionPeriodEnd` | Time | End of current billing period |
| `chargeType` | String | Billing type |

### Contact
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Contact ID |
| `name` | String | Contact name |
| `email` | String | Contact email |
| `edges.storeRole` | StoreRole! | Role assignment |

### Plan
| Field | Type | Description |
|-------|------|-------------|
| `id` | ID! | Plan ID |
| `name` | String | Plan display name |
| `price` | Float | Price amount |
| `chargeType` | String | Billing type |
| `planType` | String | PRODUCT, ADDON, SERVICE |
| `shopifySubscriptionInterval` | String | MONTHLY, YEARLY |
