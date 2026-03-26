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

## First-run behavior

On first invocation in a session:
1. Check gws is installed and authenticated (see email-tools skill prerequisites)
2. Run `gws auth status` to confirm the active account
3. Show the active account to the user before proceeding

## Routing

If an argument was provided (e.g., `/email triage`, `/email send Bob the report`), execute that action directly using the email-tools skill.

If no argument was provided, show this menu:

**Gmail Assistant** — What would you like to do?

 1. **triage** — Scan and clean up your inbox
 2. **send** — Compose and send an email
 3. **reply** — Reply to a message or thread
 4. **forward** — Forward a message
 5. **search** — Search your email
 6. **read** — Read a specific message
 7. **labels** — Manage your labels

Pick a number or describe what you need.

## Interaction style

Always present email lists as numbered items so the user can select by number (e.g., "1,3,5" or "1-5" or "all"). See the email-tools skill section on Interactive Selection UX.
