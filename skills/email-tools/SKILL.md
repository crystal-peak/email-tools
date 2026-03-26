---
name: email-tools
description: >-
  This skill should be used when the user asks to "check my email",
  "clean up my inbox", "email triage", "send an email", "reply to",
  "forward this", "search my email", "archive emails", "label emails",
  "delete emails", "unsubscribe", or invokes /email. Provides Gmail
  management via the gws CLI.
---

# Email Tools

Manage Gmail entirely from the command line using the `gws` CLI.

## CRITICAL RULES — Read before every action

1. **CONFIRM before destructive actions.** Before archiving, trashing, or deleting ANY messages, FIRST show the user what will happen ("This will trash 12 messages: [list]") and ask "Confirm? (yes/no)". NEVER execute without a "yes".

2. **ALWAYS use batchModify for 2+ messages.** NEVER loop through messages one at a time. One API call handles up to 1000 messages:
   ```bash
   # Archive bulk
   gws gmail users messages batchModify --params '{"ids":["ID1","ID2","ID3"],"userId":"me","removeLabelIds":["INBOX"]}'
   # Trash bulk
   gws gmail users messages batchModify --params '{"ids":["ID1","ID2","ID3"],"userId":"me","addLabelIds":["TRASH"]}'
   ```

3. **API methods use `--params` for ALL parameters.** There are NO `--user-id`, `--message-id`, `--max-results`, or `--label-ids` flags. Everything goes in the JSON:
   ```bash
   gws gmail users messages list --params '{"q":"is:unread","userId":"me","maxResults":50}'
   gws gmail users messages trash --params '{"userId":"me","id":"MSG_ID"}'
   ```

4. **Subcommands are SPACE-separated.** `gws gmail users messages list` — NOT `gws gmail list`, NOT `gws gmail.users.messages.list`.

5. **Prefer archive over delete.** When the user says "delete", suggest archiving instead. Only trash if they specifically insist on delete/trash.

## Helper Commands (shortcuts — use these when possible)

```bash
gws gmail +triage [--max N] [--format json] [--query 'QUERY']  # Read-only inbox summary
gws gmail +send --to EMAIL --subject "..." --body "..."         # Send (use --dry-run to preview)
gws gmail +reply --message-id MSG_ID --body "..."               # Reply with auto-threading
gws gmail +reply-all --message-id MSG_ID --body "..."           # Reply-all
gws gmail +forward --message-id MSG_ID --to EMAIL               # Forward
gws gmail +read --id MSG_ID [--headers]                         # Read message content
gws gmail +watch --project PROJECT_ID                           # Stream new emails (NDJSON)
```

## API Methods (when helpers aren't enough)

```bash
# Search/list messages
gws gmail users messages list --params '{"q":"QUERY","userId":"me","maxResults":500}' [--page-all]

# Get message metadata (for categorization)
gws gmail users messages get --params '{"id":"MSG_ID","userId":"me","format":"metadata","metadataHeaders":["From","To","Subject","List-Unsubscribe"]}'

# Modify labels (single message)
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","removeLabelIds":["INBOX"]}'

# Modify labels (BULK — always use this for 2+ messages)
gws gmail users messages batchModify --params '{"ids":["ID1","ID2",...],"userId":"me","removeLabelIds":["INBOX"]}'

# Trash single message
gws gmail users messages trash --params '{"userId":"me","id":"MSG_ID"}'

# Get user profile
gws gmail users getProfile --params '{"userId":"me"}'

# List labels
gws gmail users labels list --params '{"userId":"me"}'
```

---

## 1. Prerequisites

Run these checks silently and act on the first failure — do not dump all checks on the user at once.

```bash
which gws 2>/dev/null && gws auth status 2>&1
```

- **gws not found** → "The gws CLI isn't installed yet. Let me walk you through the setup." Follow `references/setup-guide.md` from Step 1.
- **`auth_method: none`** or **`client_config_exists: false`** → First ask which Gmail accounts they want to manage, then walk through Google Cloud setup. Follow `references/setup-guide.md` from Step 2.
- **`has_refresh_token: false`** or **`token_valid: false`** → "gws is set up but needs you to log in." Instruct: `! gws auth login -s gmail`
- **`token_valid: true`** → Ready. Fetch profile:

```bash
gws gmail users getProfile --params '{"userId":"me"}'
```

Store the `emailAddress` for triage heuristics. Show: "Connected as alice@example.com."

### Switching accounts

One active account at a time. To switch: `! gws auth login -s gmail` (picks new account in browser). The new account must be a test user in Google Cloud Console first. See `references/setup-guide.md`.

---

## 2. Triage/Cleanup Flow

Three phases. Do not skip or combine.

### Phase 1 — Scan

Get unread count:

```bash
gws gmail users messages list --params '{"q":"is:unread in:inbox","maxResults":1,"userId":"me"}'
```

Check `resultSizeEstimate` and adapt:

**Under 100 unread:** Use `gws gmail +triage --max 100 --format json` for overview and categorize individually.

**100–500 unread:** Fetch all IDs with `--page-all`, categorize in batches of 50.

**500+ unread:** Use targeted queries to find noise categories first:
```bash
gws gmail users messages list --params '{"q":"is:unread in:inbox from:notifications@github.com","userId":"me"}' --page-all
gws gmail users messages list --params '{"q":"is:unread in:inbox list:unsubscribe","userId":"me"}' --page-all
gws gmail users messages list --params '{"q":"is:unread in:inbox from:noreply","userId":"me"}' --page-all
```
Show breakdown by category with counts. Let user pick which to archive in bulk.

**0 unread:** "Your inbox is clean!"

### Phase 2 — Categorize

Apply heuristics from `references/triage-heuristics.md`. Assign each message to Keep, Archive, or Unsure.

### Phase 3 — Display and Act

Show grouped summary with numbered lists. Wait for user to tell you what to do.

**When the user says to archive or delete:**
1. Show exactly what will happen: "This will archive 15 messages: Newsletters (8), GitHub (4), Marketing (3). Confirm?"
2. Wait for explicit "yes"
3. Execute with ONE `batchModify` call:
   ```bash
   gws gmail users messages batchModify --params '{"ids":["id1","id2","id3",...],"userId":"me","removeLabelIds":["INBOX"]}'
   ```
4. For trash: use `"addLabelIds":["TRASH"]` instead
5. Report result: "Archived 15 messages."

**NEVER loop through messages individually. ALWAYS use batchModify.**

---

## 3. Composing Email (Send / Reply / Forward)

**ALWAYS preview before sending.** Show the draft (recipients, subject, body) and wait for "yes".

```bash
gws gmail +send --to EMAIL --subject "..." --body "..." --dry-run   # Preview
gws gmail +send --to EMAIL --subject "..." --body "..."             # Send after confirmation
gws gmail +reply --message-id MSG_ID --body "..."                   # Reply
gws gmail +forward --message-id MSG_ID --to EMAIL                   # Forward
```

Use `--draft` to save without sending. Use `--html` for HTML content.

---

## 4. Search and Read

```bash
gws gmail users messages list --params '{"q":"from:alice subject:report after:2026/03/01","userId":"me"}'
gws gmail +read --id MSG_ID --headers
```

Only read message bodies when the user explicitly asks. During triage/search, use metadata only.

See `references/gws-gmail-commands.md` for the full Gmail query syntax cheat sheet.

---

## 5. Label and Archive Operations

```bash
gws gmail users labels list --params '{"userId":"me"}'                                                    # List labels
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","removeLabelIds":["INBOX"]}'       # Archive one
gws gmail users messages batchModify --params '{"ids":[...],"userId":"me","removeLabelIds":["INBOX"]}'    # Archive bulk
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","addLabelIds":["LABEL_ID"]}'       # Add label
```

---

## 6. Interactive Selection UX

Present all email lists as numbered items. After showing a list, accept selection by number:

- `3` → item 3
- `1,3,5` → items 1, 3, 5
- `1-5` → items 1 through 5
- `all` → all items
- `none` / `skip` → no action

Maintain an internal mapping of display number → message ID. Resolve to actual IDs before executing commands.

---

## 7. Reference Files

- **`references/setup-guide.md`** — First-time setup walkthrough, OAuth, troubleshooting
- **`references/gws-gmail-commands.md`** — Full command reference, query syntax, all parameters
- **`references/triage-heuristics.md`** — Categorization rules, batch processing, output format
