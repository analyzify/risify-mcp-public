# Flow: Support & Service Requests

Open support tickets with the Risify team and manage professional service requests.

## Support Ticket

### Create a Support Ticket

1. Ask user for:
   - **Topic** — what they need help with
   - **Message** — detailed description of the issue

2. Optionally ask for additional email recipients

3. Create the ticket:

```graphql
mutation {
  createSupportTicket(input: {
    topic: "Issue with FAQ display"
    message: "FAQs are not showing on my product pages after I assigned them yesterday."
  })
}
```

Returns `true` if ticket was created successfully.

4. Confirm: "Support ticket created. The Risify team will respond to your email."

## Service Requests

### List Service Requests

```graphql
query { serviceRequestList(page: 1, limit: 10, serviceId: null) { nodes { id status displayStatus notes edges { service { name } } createdAt dateCompleted } totalCount } }
```

Present as:

```text
Service Requests ({totalCount}):

1. {service.name} — {displayStatus}
   Created: {createdAt}
   {dateCompleted ? "Completed: " + dateCompleted : ""}

2. ...
```

### View Service Request Details

```graphql
query { serviceRequestGet(id: "<request-id>") { id status displayStatus notes videoLink pdfLink implementationLogs validationProofLinks dateCompleted edges { service { name } } } }
```

Present:
```text
Service: {service.name}
Status: {displayStatus}
{notes ? "Notes: " + notes : ""}
{videoLink ? "Video: " + videoLink : ""}
{pdfLink ? "PDF: " + pdfLink : ""}
{implementationLogs ? "Logs: " + implementationLogs : ""}
```

### Cancel a Service Request

1. **Confirm before cancelling:** "Cancel service request '{service.name}'? Are you sure?"
2. Cancel:

```graphql
mutation { serviceRequestCancel(id: "<request-id>") { id status displayStatus } }
```

3. Confirm: "Service request cancelled."

## Error Handling

| Situation | Response |
|-----------|----------|
| Ticket creation fails | Check that topic and message are provided |
| Service request not found | Verify the ID is correct |
| Cannot cancel | Request may already be completed or cancelled |
