---
name: email
description: Gmail assistant — triage inbox, send, reply, forward, search, and manage email
argument-hint: [action or request]
allowed-tools:
  - Agent
  - Read
---

# /email — Gmail Assistant

This command delegates ALL Gmail operations to the `email-tools:gmail` agent. Do NOT run gws commands directly — the agent handles everything and returns clean summaries.

## How to delegate

Use the Agent tool with `subagent_type: "email-tools:gmail"` for every operation. The agent has pre-approved bash permissions for gws commands so nothing prompts the user.

**Examples:**

Triage:
```
Agent(subagent_type: "email-tools:gmail", prompt: "Triage the inbox. Return categorized list with numbered items, message IDs, senders, and subjects.")
```

Trash/Archive (after user confirms):
```
Agent(subagent_type: "email-tools:gmail", prompt: "Trash these message IDs using batchModify: ID1, ID2, ID3")
```

Search:
```
Agent(subagent_type: "email-tools:gmail", prompt: "Search for emails from:bob after:2026/03/01. Return numbered list.")
```

Read:
```
Agent(subagent_type: "email-tools:gmail", prompt: "Read message ID 19d2c097c249deb8 with headers.")
```

## Confirmation rule

When the user asks to archive, trash, or delete messages:
1. Show what will happen: "This will trash 6 messages: [list]. Confirm?"
2. Wait for "yes"
3. THEN delegate to the agent to execute

The agent runs commands silently. The user only sees your clean summary.

## First-run behavior

On first invocation, delegate to the agent to check setup:
```
Agent(subagent_type: "email-tools:gmail", prompt: "Check if gws is installed and authenticated. Read ~/.config/email-tools/accounts.json for configured accounts. Return: installed (yes/no), active account email and label, total accounts count.")
```

If not set up, walk user through setup per the email-tools skill.

## Menu

If no argument provided, show:

**Gmail Assistant** (active: alice@example.com) — What would you like to do?

 1. **triage** — Scan and clean up your inbox
 2. **send** — Compose and send an email
 3. **reply** — Reply to a message or thread
 4. **forward** — Forward a message
 5. **search** — Search your email
 6. **read** — Read a specific message
 7. **labels** — Manage your labels
 8. **switch account** — Change active Gmail account
 9. **add account** — Add another Gmail account

## Interaction style

Present email lists as numbered items. Accept selection by number (1, 1-5, 1,3,5, all).

The agent returns results with message IDs mapped to display numbers. Maintain this mapping for follow-up actions.
