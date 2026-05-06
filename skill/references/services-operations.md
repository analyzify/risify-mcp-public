# Support & Services GraphQL Operations Reference

All operations use the `execute_graphql` MCP tool directly against the Risify API.

---

## Queries

### List Service Requests
```graphql
query {
  serviceRequestList(page: 1, limit: 10, serviceId: null) {
    nodes {
      id
      status
      displayStatus
      notes
      createdAt
      updatedAt
      dateCompleted
      edges {
        service {
          id
          name
          status
          slug
        }
      }
    }
    totalCount
    totalPage
    currentPage
  }
}
```

### Get Service Request Details
```graphql
query {
  serviceRequestGet(id: "<request-id>") {
    id
    status
    displayStatus
    notes
    videoLink
    pdfLink
    implementationLogs
    validationProofLinks
    dateCompleted
    createdAt
    updatedAt
    businessName
    websiteUrl
    primaryContactName
    primaryContactEmail
    edges {
      service {
        id
        name
        slug
      }
    }
  }
}
```

---

## Mutations

### Create Support Ticket
```graphql
mutation {
  createSupportTicket(input: {
    topic: "Issue description"
    message: "Detailed message about the issue or request"
    additionalEmails: ["colleague@example.com"]
  })
}
```

Returns `Boolean` — `true` if ticket was created.

### Cancel Service Request
```graphql
mutation {
  serviceRequestCancel(id: "<request-id>") {
    id
    status
    displayStatus
  }
}
```
