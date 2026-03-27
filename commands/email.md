---
name: email
description: Gmail assistant — triage inbox, send, reply, forward, search, and manage email
argument-hint: [action or request]
allowed-tools:
  - Bash
  - Read
---

# /email — Gmail Assistant

This command provides full Gmail management via the gws CLI. Use the email-tools skill for all operations.

## MANDATORY BEHAVIORAL RULES — NEVER SKIP

**RULE 1 — ALWAYS CONFIRM BEFORE ACTING ON MESSAGES.**
When the user asks to archive, trash, delete, or modify messages:
- FIRST output a confirmation message: "This will [action] [N] messages: [list]. Confirm? (yes/no)"
- STOP and WAIT for the user to reply "yes"
- DO NOT execute any gws command until you receive confirmation
- This applies even if the user says "delete promos" or "trash all" — still confirm first

**RULE 2 — NEVER TRASH/ARCHIVE MESSAGES ONE AT A TIME.**
When acting on 2 or more messages, use exactly ONE batchModify call:
```bash
# Archive multiple messages (ONE call, not a loop):
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["ID1","ID2","ID3"],"removeLabelIds":["INBOX"]}'

# Trash multiple messages (ONE call, not a loop):
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["ID1","ID2","ID3"],"addLabelIds":["TRASH"]}'
```
DO NOT call `gws gmail users messages trash` in a loop for each message. That is wrong. Use batchModify.

**RULE 3 — ALL API parameters go in --params JSON.**
There are no `--user-id`, `--message-id`, `--max-results` flags. Everything is JSON:
```bash
gws gmail users messages trash --params '{"userId":"me","id":"MSG_ID"}'
```

## First-run behavior

On first invocation in a session:
1. Check gws is installed (see email-tools skill prerequisites)
2. Read `~/.config/email-tools/accounts.json` to get configured accounts
3. If no accounts configured, walk user through setup per `references/multi-account.md`
4. Show the active account before proceeding: "Connected as alice@example.com (personal)"

## Routing

If an argument was provided (e.g., `/email triage`, `/email send Bob the report`), execute that action directly using the email-tools skill.

If no argument was provided, show this menu:

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

Pick a number or describe what you need.

## Interaction style

Always present email lists as numbered items so the user can select by number (e.g., "1,3,5" or "1-5" or "all"). See the email-tools skill section on Interactive Selection UX.
