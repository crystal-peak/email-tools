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

## MANDATORY RULES — NEVER SKIP

### RULE 1: ALWAYS CONFIRM BEFORE ACTING
Before archiving, trashing, or deleting ANY messages:
1. Output: "This will [action] [N] messages: [list senders/subjects]"
2. Ask: "Confirm? (yes/no)"
3. STOP. Do NOT call any gws command. Wait for the user to say "yes".
4. Only after receiving "yes", proceed to execute.

This applies EVERY time, even if the user says "delete them", "trash all", "archive promos". Always confirm first.

### RULE 2: USE batchModify FOR BULK — NEVER LOOP
When acting on 2+ messages, make exactly ONE batchModify call with all IDs in an array. Do NOT call trash/modify in a loop for each message ID.

**CORRECT (one call for all messages):**
```bash
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["ID1","ID2","ID3","ID4","ID5"],"addLabelIds":["TRASH"]}'
```

**WRONG (calling trash individually for each — NEVER DO THIS):**
```bash
gws gmail users messages trash --params '{"userId":"me","id":"ID1"}'
gws gmail users messages trash --params '{"userId":"me","id":"ID2"}'
gws gmail users messages trash --params '{"userId":"me","id":"ID3"}'
```

### RULE 3: ALL API parameters go in --params JSON
There are NO `--user-id`, `--message-id`, `--max-results`, or `--label-ids` flags on API methods. Everything goes inside `--params` as JSON.

### RULE 4: Space-separated subcommands
`gws gmail users messages list` — NOT `gws gmail list`

### RULE 5: Prefer archive over delete
When the user says "delete", suggest archiving instead. Only trash if they insist.

## Multi-Account Support

All gws commands MUST be prefixed with the active account's config directory. Before running any gws command, read the state file:

```bash
cat ~/.config/email-tools/accounts.json 2>/dev/null
```

Then prefix every gws command with the active account's `config_dir`:

```bash
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=CONFIG_DIR gws gmail +triage --format json
```

If no state file exists, follow `references/multi-account.md` to set up accounts. If a default `~/.config/gws` auth exists, migrate it first.

When the user says "switch account", "add account", "remove account", "use my work email", etc., follow `references/multi-account.md`.

## Helper Commands (shortcuts — use these when possible)

All commands below assume the `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=CONFIG_DIR` prefix is added.

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
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["ID1","ID2",...],"removeLabelIds":["INBOX"]}'

# Trash single message
gws gmail users messages trash --params '{"userId":"me","id":"MSG_ID"}'

# Get user profile
gws gmail users getProfile --params '{"userId":"me"}'

# List labels
gws gmail users labels list --params '{"userId":"me"}'
```

---

## 1. Prerequisites

Run these checks silently and act on the first failure.

**Step 1 — Check gws installed:**
```bash
which gws 2>/dev/null
```
If not found → follow `references/setup-guide.md` from Step 1.

**Step 2 — Check accounts state:**
```bash
cat ~/.config/email-tools/accounts.json 2>/dev/null
```
- **State file exists** → Read the active account, set `CONFIG_DIR` from it, proceed to Step 3.
- **No state file** → Check if default gws auth exists (`gws auth status`). If yes, migrate it to multi-account setup per `references/multi-account.md`. If no auth at all, follow `references/setup-guide.md` then `references/multi-account.md`.

**Step 3 — Verify active account:**
```bash
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=CONFIG_DIR gws gmail users getProfile --params '{"userId":"me"}'
```
If this fails, the token may be expired. Instruct: `! GOOGLE_WORKSPACE_CLI_CONFIG_DIR=CONFIG_DIR gws auth login -s gmail`

Show: "Connected as alice@example.com (personal). You have N accounts configured."

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
   gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["id1","id2","id3",...],"removeLabelIds":["INBOX"]}'
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
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":[...],"removeLabelIds":["INBOX"]}'    # Archive bulk
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
- **`references/multi-account.md`** — Multi-account management, adding/switching/removing accounts, state file format
- **`references/gws-gmail-commands.md`** — Full command reference, query syntax, all parameters
- **`references/triage-heuristics.md`** — Categorization rules, batch processing, output format
