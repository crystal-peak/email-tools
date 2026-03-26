# gws CLI — Gmail Command Reference

Reference for managing Gmail via the Google Workspace CLI (`gws`).
Install: `npm install -g @googleworkspace/cli`

---

## Authentication & Setup

### Interactive OAuth Setup (Desktop)

```bash
gws auth setup
```

Creates a Google Cloud project and enables APIs. Requires `gcloud` CLI.

### Scope-Limited Login

```bash
gws auth login -s gmail
```

Authenticate with only Gmail scopes. Omit `-s` to authenticate all services.

### Check Auth Status

```bash
gws auth status
```

### Verify Gmail Access

```bash
gws gmail users.getProfile --params '{"userId":"me"}'
```

Returns the authenticated user's email address and message/thread totals. Use this to confirm auth is working before running other commands.

### Export Credentials (Headless/CI)

```bash
gws auth export --unmasked > credentials.json
```

Complete interactive auth on a machine with a browser, then transfer the exported file. On the headless machine, set:

```bash
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=./credentials.json
```

### Credential Precedence

1. `GOOGLE_WORKSPACE_CLI_TOKEN` — pre-obtained access token
2. `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` — path to credentials JSON
3. Encrypted credentials from `gws auth login`
4. Plaintext `~/.config/gws/credentials.json`

---

## Helper Commands (+ Prefixed Shortcuts)

Helper commands provide human-friendly interfaces over the raw API. All helpers return structured JSON.

### +triage — Unread Inbox Summary

```bash
gws gmail +triage
gws gmail +triage --max 20
gws gmail +triage --query "from:boss@company.com"
gws gmail +triage --labels "IMPORTANT"
gws gmail +triage --format table
```

| Flag | Description | Default |
|------|-------------|---------|
| `--max` | Maximum messages to return | 10 |
| `--query` | Gmail search query to filter results | (none) |
| `--labels` | Comma-separated label IDs to filter by | INBOX |
| `--format` | Output format: `json` or `table` | json |

### +send — Send Email

```bash
gws gmail +send --to alice@example.com --subject "Q1 Report" --body "See attached."
gws gmail +send --to alice@example.com --cc bob@example.com --bcc cfo@example.com \
  --subject "Q1 Report" --body "See attached." --attach ./report.pdf
gws gmail +send --to alice@example.com --subject "Newsletter" --html ./email.html
gws gmail +send --to alice@example.com --subject "Draft" --body "WIP" --draft
gws gmail +send --to alice@example.com --subject "Test" --body "Preview" --dry-run
```

| Flag | Description | Required |
|------|-------------|----------|
| `--to` | Recipient email address(es) | Yes |
| `--subject` | Email subject line | Yes |
| `--body` | Plain text message body | Yes (or `--html`) |
| `--cc` | Carbon copy recipient(s) | No |
| `--bcc` | Blind carbon copy recipient(s) | No |
| `--html` | Path to HTML file for rich email body | No |
| `--attach` | Path to file attachment | No |
| `--draft` | Save as draft instead of sending | No |
| `--dry-run` | Preview the request without sending | No |

### +reply — Reply to Message

```bash
gws gmail +reply --message-id MESSAGE_ID --body "Thanks, received."
gws gmail +reply --message-id MESSAGE_ID --body "See attached." --attach ./notes.pdf
gws gmail +reply --message-id MESSAGE_ID --body "Noted." --cc manager@example.com
gws gmail +reply --message-id MESSAGE_ID --body "Draft reply" --draft
```

| Flag | Description | Required |
|------|-------------|----------|
| `--message-id` | ID of the message to reply to | Yes |
| `--body` | Reply text | Yes |
| `--cc` | Additional CC recipient(s) | No |
| `--html` | Path to HTML file for rich reply body | No |
| `--attach` | Path to file attachment | No |
| `--draft` | Save as draft instead of sending | No |

### +reply-all — Reply All

```bash
gws gmail +reply-all --message-id MESSAGE_ID --body "Acknowledged by all."
```

Same flags as `+reply`. Automatically includes all original To/CC recipients.

### +forward — Forward Message

```bash
gws gmail +forward --message-id MESSAGE_ID --to colleague@example.com
gws gmail +forward --message-id MESSAGE_ID --to colleague@example.com --body "FYI"
```

| Flag | Description | Required |
|------|-------------|----------|
| `--message-id` | ID of message to forward | Yes |
| `--to` | Forwarding recipient(s) | Yes |
| `--body` | Additional message text prepended to forward | No |

### +read — Read Message Content

```bash
gws gmail +read --message-id MESSAGE_ID
```

| Flag | Description | Required |
|------|-------------|----------|
| `--message-id` | ID of message to read | Yes |

Returns the full message content including headers, body, and attachment metadata.

### +watch — Stream Incoming Emails (NDJSON)

```bash
gws gmail +watch
gws gmail +watch --project my-gcp-project --label-ids "INBOX"
gws gmail +watch --poll-interval 30
gws gmail +watch --once
gws gmail +watch --output-dir ./emails --cleanup
```

| Flag | Description | Default |
|------|-------------|---------|
| `--project` | GCP project ID for Pub/Sub | Auto-detected |
| `--label-ids` | Comma-separated label IDs to watch | INBOX |
| `--poll-interval` | Seconds between polls | 60 |
| `--once` | Fetch once and exit (no streaming) | false |
| `--output-dir` | Write each message to a file in this directory | (none) |
| `--cleanup` | Remove Pub/Sub resources on exit | false |

Output is newline-delimited JSON (NDJSON), one JSON object per new message.

---

## API Methods

All API methods use the pattern: `gws gmail <resource>.<method> --params '<JSON>' --json '<JSON>'`

The `userId` parameter defaults to `"me"` in most contexts. Always pass it explicitly.

### users.messages list — Search/List Messages

```bash
gws gmail users.messages list --params '{"userId":"me","q":"is:unread","maxResults":10}'
gws gmail users.messages list --params '{"userId":"me","q":"from:alice@example.com","labelIds":["INBOX"]}' --page-all
gws gmail users.messages list --params '{"userId":"me","q":"newer_than:1d"}' --page-all --page-limit 5
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `userId` | string | User ID or `"me"` |
| `q` | string | Gmail search query (same syntax as Gmail search box) |
| `maxResults` | integer | Max messages per page (1-500, default 100) |
| `labelIds` | string[] | Filter by label IDs |
| `pageToken` | string | Token for next page of results |
| `includeSpamTrash` | boolean | Include spam and trash results |

Pagination flags:
- `--page-all` — auto-paginate, output NDJSON (one JSON object per page)
- `--page-limit <N>` — max pages to fetch (default 10)
- `--page-delay <MS>` — delay between pages (default 100ms)

Returns `messages` array with `id` and `threadId` for each message. Use `users.messages get` to fetch full content.

### users.messages get — Get Single Message

```bash
gws gmail users.messages get --params '{"userId":"me","id":"MESSAGE_ID","format":"full"}'
gws gmail users.messages get --params '{"userId":"me","id":"MESSAGE_ID","format":"metadata","metadataHeaders":["From","Subject","Date"]}'
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `userId` | string | User ID or `"me"` |
| `id` | string | Message ID |
| `format` | string | `full` (default), `metadata`, `minimal`, `raw` |
| `metadataHeaders` | string[] | Headers to include when format is `metadata` |

Format options:
- `full` — parsed message with all parts, headers, and body
- `metadata` — headers only, no body content
- `minimal` — ID, labels, and snippet only
- `raw` — full RFC 2822 message as base64url string

### users.messages modify — Modify Labels (Single Message)

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MESSAGE_ID"}' \
  --json '{"addLabelIds":["STARRED"],"removeLabelIds":["UNREAD"]}'
```

| Body Field | Type | Description |
|------------|------|-------------|
| `addLabelIds` | string[] | Label IDs to add |
| `removeLabelIds` | string[] | Label IDs to remove |

### users.messages.batchModify — Bulk Modify Labels

```bash
gws gmail users.messages.batchModify --params '{"userId":"me"}' \
  --json '{"ids":["MSG_1","MSG_2","MSG_3"],"addLabelIds":["Label_5"],"removeLabelIds":["INBOX"]}'
```

| Body Field | Type | Description |
|------------|------|-------------|
| `ids` | string[] | Message IDs (max 1000 per request) |
| `addLabelIds` | string[] | Label IDs to add to all messages |
| `removeLabelIds` | string[] | Label IDs to remove from all messages |

### users.messages delete — Permanently Delete

```bash
gws gmail users.messages delete --params '{"userId":"me","id":"MESSAGE_ID"}'
```

**DANGEROUS: Permanently deletes the message. Cannot be undone. Prefer `trash` instead.**

### users.messages trash — Move to Trash

```bash
gws gmail users.messages trash --params '{"userId":"me","id":"MESSAGE_ID"}'
```

Moves the message to Trash. Can be recovered within 30 days.

### users.labels list — List All Labels

```bash
gws gmail users.labels list --params '{"userId":"me"}'
```

Returns all system and user labels with their IDs. Use label IDs (not names) in `modify` and `batchModify` calls.

### users.getProfile — Get Authenticated User's Profile

```bash
gws gmail users.getProfile --params '{"userId":"me"}'
```

Returns `emailAddress`, `messagesTotal`, `threadsTotal`, and `historyId`.

---

## Gmail Query Syntax Cheat Sheet

Use these operators in the `q` parameter of `users.messages list` or the `--query` flag of `+triage`. Same syntax as the Gmail search box.

### Sender & Recipient

| Operator | Description |
|----------|-------------|
| `from:alice@example.com` | Messages from sender |
| `to:bob@example.com` | Messages to recipient |
| `cc:carol@example.com` | Messages CC'd to |
| `bcc:dave@example.com` | Messages BCC'd to |

### Subject & Content

| Operator | Description |
|----------|-------------|
| `subject:quarterly report` | Words in subject line |
| `"exact phrase"` | Exact phrase match in body or subject |

### Status Flags

| Operator | Description |
|----------|-------------|
| `is:unread` | Unread messages |
| `is:read` | Read messages |
| `is:starred` | Starred messages |
| `is:important` | Marked important |
| `is:snoozed` | Snoozed messages |
| `is:muted` | Muted conversations |

### Location

| Operator | Description |
|----------|-------------|
| `in:inbox` | Inbox messages |
| `in:sent` | Sent messages |
| `in:draft` | Draft messages |
| `in:trash` | Trash |
| `in:spam` | Spam |
| `in:archive` | Archived (not in Inbox) |
| `in:anywhere` | All mail including spam and trash |
| `label:projects` | Messages with specific label |

### Attachments

| Operator | Description |
|----------|-------------|
| `has:attachment` | Has any attachment |
| `filename:pdf` | Attachment with file type |
| `filename:report.xlsx` | Attachment with specific name |

### Date Ranges

| Operator | Description |
|----------|-------------|
| `after:2025/01/01` | After date (YYYY/MM/DD) |
| `before:2025/12/31` | Before date |
| `older_than:7d` | Older than 7 days |
| `older_than:3m` | Older than 3 months |
| `older_than:1y` | Older than 1 year |
| `newer_than:1d` | Newer than 1 day |
| `newer_than:2w` | Newer than 2 weeks |

### Size

| Operator | Description |
|----------|-------------|
| `larger:5M` | Larger than 5 MB |
| `smaller:100K` | Smaller than 100 KB |
| `size:1000000` | Exact size in bytes |

### Boolean Operators

| Operator | Description |
|----------|-------------|
| (space) | AND — both terms must match |
| `OR` | Either term matches |
| `-` | NOT — exclude term |
| `()` | Grouping |

### Combined Examples

```
# Unread from boss in last week
from:boss@company.com is:unread newer_than:7d

# Large attachments older than a year
has:attachment larger:10M older_than:1y

# Inbox messages from team, not newsletters
in:inbox (from:alice OR from:bob) -label:newsletters

# Unread with PDF attachments
is:unread has:attachment filename:pdf

# Messages in a date range
after:2025/01/01 before:2025/03/31 from:client@example.com
```

---

## Common Operations Quick Reference

### Archive a Message

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"removeLabelIds":["INBOX"]}'
```

### Mark as Read

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"removeLabelIds":["UNREAD"]}'
```

### Mark as Unread

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"addLabelIds":["UNREAD"]}'
```

### Star a Message

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"addLabelIds":["STARRED"]}'
```

### Move to Trash

```bash
gws gmail users.messages trash --params '{"userId":"me","id":"MSG_ID"}'
```

Or via label modification:

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"addLabelIds":["TRASH"]}'
```

### Apply a User Label

Look up the label ID first:

```bash
gws gmail users.labels list --params '{"userId":"me"}'
```

Then apply it:

```bash
gws gmail users.messages modify --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"addLabelIds":["Label_5"]}'
```

### Bulk Archive (Up to 1000 Messages)

```bash
gws gmail users.messages.batchModify --params '{"userId":"me"}' \
  --json '{"ids":["MSG_1","MSG_2","MSG_3"],"removeLabelIds":["INBOX"]}'
```

### Bulk Mark as Read

```bash
gws gmail users.messages.batchModify --params '{"userId":"me"}' \
  --json '{"ids":["MSG_1","MSG_2"],"removeLabelIds":["UNREAD"]}'
```

---

## Output Format Notes

- **Helper commands** (`+send`, `+triage`, etc.) output structured JSON by default. Use `--format table` where supported for human-readable output.
- **API methods** output structured JSON matching the Gmail API response schema.
- **`--page-all`** streams NDJSON — one JSON object per page, newline-separated. Pipe to `jq` for filtering.
- **`+watch`** streams NDJSON — one JSON object per incoming message.
- **`--dry-run`** prints the HTTP request that would be sent without executing it.

### Filtering Output with jq

```bash
# Extract message IDs from a list
gws gmail users.messages list --params '{"userId":"me","q":"is:unread"}' | jq -r '.messages[].id'

# Get subject lines from full messages
gws gmail users.messages get --params '{"userId":"me","id":"MSG_ID","format":"metadata","metadataHeaders":["Subject"]}' \
  | jq -r '.payload.headers[] | select(.name=="Subject") | .value'
```

### Schema Introspection

```bash
gws schema gmail.users.messages.list
gws schema gmail.users.messages.get
```

Use `gws schema` to inspect any method's parameters and response shape.
