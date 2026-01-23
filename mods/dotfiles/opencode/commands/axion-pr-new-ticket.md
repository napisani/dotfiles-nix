---
description: Create A PR with a new, currently non-existent, ticket 
agent: axion-pr-opener 
model: cursor/grok 
---

Do the following, in this order:
1. create a new JIRA ticket in the "ECO" project with the following details:
    - Summary - this should be a short description of the staged changes or underlying issue being addressed IE: "Implement feature X to enhance user experience" 
    - Description: Provide a brief overview of the change, clarifying details as necessary. Keep it concise yet informative. This should be at most a couple of sentences.
    - Issue Type: Task
    - Priority: Medium
    - Assign the ticket to me (the current user) 
    - Story Points: 3 
    - Sprint: Assign to the current active sprint 
    - Status: In Review 



2. Create a Github pull request in the current repository using the standard convention. Use the newly created ticket URL to populate the part of the template for the JIRA ticket link. 

3. Finally, prepare a concise communication message summarizing the PR in 1 or 2 sentences, suitable for sharing with team members. The message should highlight the key changes and their purpose. This message should be followed by the PR link.
Here is an example:

```
This PR introduces group-by logic on the bar chart to support the new customer X use case.
PR:
<PR_LINK>
```
