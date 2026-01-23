---
description: Create A PR with a new, currently non-existent, ticket 
agent: axion-pr-opener 
model: cursor/grok 
---

Do the following, in this order:
1. Identify an existing Jira ticket in the ECO project that is assigned to me, in the current sprint that is related to the staged changes. If you are unsure about which ticket relates to the changes staged in this branch. 
MAKE SURE to ask me to select from a list of relevant tickets before proceeding.

2. Create a Github pull request in the current repository using the standard convention. Use the identified ticket URL to populate the part of the template for the JIRA ticket link. 

3. Finally, prepare a concise communication message summarizing the PR in 1 or 2 sentences, suitable for sharing with team members. The message should highlight the key changes and their purpose. This message should be followed by the PR link.
Here is an example:

```
This PR introduces group-by logic on the bar chart to support the new customer X use case.
PR:
<PR_LINK>
```
