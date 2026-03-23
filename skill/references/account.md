# Flow: Account Management

View account details, manage subscription and billing, handle team contacts, and check AI credits. All direct Risify API calls — no shopifyProxy needed.

## Capabilities

### 1. View Account Info

```graphql
query {
  me {
    id firstName lastName fullName email
    shopUrl shopName shopSlug domain status
    purchaseDate currencyCode
    isAppSubscriptionPlanActive appEmbedStatus
    subTrialDays subCanTrial supportPeriodEndDate
    appSubscriptionCharge {
      id name price status subscriptionPeriodEnd chargeType createdAt
      edges { plan { id name price planType chargeType headline description } }
    }
  }
}
```

ALWAYS use this exact template:

```
**Store:** {shopName}
**URL:** {shopUrl}
**Domain:** {domain}
**Owner:** {fullName} ({email})
**Member since:** {purchaseDate}
**Plan:** {appSubscriptionCharge.name} ({appSubscriptionCharge.status})
**Next billing:** {appSubscriptionCharge.subscriptionPeriodEnd}
**App embed:** {appEmbedStatus ? "Enabled" : "Disabled"}
```

### 2. Check AI Credits

```graphql
query { aiCreditInfo { limit usage resetAt } }
```

- `limit = -1` → unlimited. `limit = 0` → disabled.
- Available = `limit - usage`

### 3. List Team Contacts

```graphql
query {
  contactList(page: 1, limit: 10) {
    nodes { id name email createdAt edges { storeRole { id name displayName } } }
    totalCount totalPage currentPage
  }
}
```

Present as a table of team members with name, email, and role.

### 4. Add a Team Contact

First fetch available roles:
```graphql
query { storeRoleList { id name displayName } }
```

Then create:
```graphql
mutation {
  contactCreate(input: { name: "John Doe" email: "john@example.com" storeRoleId: "<role-id>" }) {
    id name email edges { storeRole { displayName } }
  }
}
```

Ask the user for: name, email, and role (present available roles to choose from).

### 5. Update a Team Contact

```graphql
mutation {
  contactUpdate(id: "<contact-id>", input: { name: "Updated Name" email: "updated@example.com" storeRoleId: "<role-id>" }) {
    id name email
  }
}
```

### 6. Delete a Team Contact

```graphql
mutation { contactDelete(id: "<contact-id>") { id name } }
```

Confirm with the user before deleting.

### 7. View Billing History

```graphql
query {
  chargeList(page: 1, limit: 10) {
    nodes { id name price appliedDiscountAmount status createdAt subscriptionPeriodEnd chargeType test }
    totalCount totalPage currentPage
  }
}
```

Present as a table. If `appliedDiscountAmount > 0`, show discounted price: `price - appliedDiscountAmount`.

### 8. View Available Plans

```graphql
query {
  planList(planType: PRODUCT) {
    nodes { id name price chargeType planType headline description tags { key value } discountAmount shopifySubscriptionInterval }
    totalCount
  }
}
```

Plan types: `PRODUCT` (subscription), `ADDON`, `SERVICE`

**Standard Plan:** 50 AI credits/month, 1 domain, 100 keywords, 10 audits/month
**Plus Plan:** 500 AI credits/month, 5 domains, 1,000 keywords, 100 audits/month

### 9. Buy/Upgrade a Plan

```graphql
mutation { planBuy(planId: "<plan-id>") { returnUrl } }
```

Returns a Shopify confirmation URL. Tell the user to visit it to complete the purchase.

### 10. Cancel Subscription

```graphql
mutation { appSubscriptionCancel(id: "<charge-id>") { id name status subscriptionPeriodEnd } }
```

The `id` is the Risify charge ID (from `me.appSubscriptionCharge.id`), NOT a Shopify charge ID.

**Always confirm** before cancelling. Warn: they lose access at `subscriptionPeriodEnd`.

### 11. Verify a Charge

```graphql
mutation { chargeVerify(chargeId: 12345) { id name status } }
```

`chargeId` is the Shopify numeric charge ID (Uint64).

## Error Handling

| Situation | Response |
|-----------|----------|
| Not authenticated | Credentials may be missing. Verify RISIFY_USER_ID and RISIFY_API_KEY |
| Plan not active | Show available plans |
| Contact create fails | Check required fields: name, email, storeRoleId |
| Cancel fails | Verify charge ID is correct and subscription is active |
| No AI credits | Direct user to upgrade plan or wait for credit reset |
