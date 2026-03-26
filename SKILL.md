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

Manage Gmail entirely from the command line using the `gws` CLI. This skill covers inbox triage, composing and sending messages, replying, forwarding, searching, reading, labeling, archiving, and deleting email.

---

## 1. Prerequisites

Before executing any Gmail operation, verify the toolchain is ready. Run these checks silently and act on the first failure found — do not dump all checks on the user at once.

### Quick diagnosis

```bash
which gws 2>/dev/null && gws auth status 2>&1
```

Based on the result, take the appropriate path:

- **gws not found** → Tell the user: "The gws CLI isn't installed yet. Let me walk you through the setup." Then follow `references/setup-guide.md` starting from Step 1.
- **`auth_method: none`** or **`client_config_exists: false`** → The CLI is installed but no Google Cloud project is configured. First, ask which Gmail accounts they want to manage (Step 2 in the setup guide). Then walk through the Google Cloud setup. Follow `references/setup-guide.md` starting from Step 2.
- **`has_refresh_token: false`** or **`token_valid: false`** → Project is configured but not logged in. Tell the user: "gws is set up but needs you to log in." Then instruct: `! gws auth login -s gmail`
- **`token_valid: true`** → Fully ready. Proceed to profile fetch.

### Verify and capture user email

```bash
gws gmail users getProfile --params '{"userId":"me"}'
```

If this succeeds, extract and store the `emailAddress` for use in triage heuristics (detecting automated notifications, identifying same-org senders, etc.). Show the user: "Connected as alice@example.com. What would you like to do?"

If this fails with an auth error despite `token_valid: true`, the token may have expired or scopes may be insufficient. Instruct: `! gws auth login -s gmail`

### Switching accounts

The gws CLI supports one active account at a time. When the user asks to "switch account", "use my other email", or "check my work email":

1. Show the currently active account: `gws auth status 2>&1 | grep '"user"'`
2. Tell the user to re-authenticate: "To switch accounts, run this in your terminal:" → `! gws auth login -s gmail`
3. Remind them: the new account must be added as a test user in their Google Cloud Console first (https://console.cloud.google.com/auth/audience → Test users). If they get "Access blocked", this is why.
4. After re-auth, verify with the profile fetch above.

### First-time setup reference

For the complete setup walkthrough (Google Cloud project creation, OAuth consent screen, client secret download, troubleshooting), consult `references/setup-guide.md`. Guide the user through it one step at a time — do not dump all steps at once.

---

## 2. Capabilities

This skill enables the following operations:

- **Triage/Cleanup** — Scan unread inbox messages, categorize them with heuristics, and batch-archive noise.
- **Send** — Compose and send new emails. Always preview before sending.
- **Reply/Reply-All** — Reply to existing threads with automatic threading.
- **Forward** — Forward individual messages to new recipients.
- **Search** — Query Gmail using the full Gmail search syntax.
- **Read** — Retrieve and display the full content of a specific message.
- **Label** — Apply or remove labels, including bulk label operations.
- **Archive** — Remove messages from the inbox without deleting them (reversible).
- **Delete** — Move messages to trash. Require explicit user confirmation before executing.

---

## 3. Triage/Cleanup Flow

Triage operates as a three-phase pipeline. Do not skip phases or combine them.

**IMPORTANT**: All gws Gmail commands use space-separated subcommands. The pattern is always `gws gmail <resource> <method>`. For example: `gws gmail users messages list`, NOT `gws gmail list` or `gws gmail messages.list`. Copy commands exactly as shown below.

### Phase 1 — Scan

Start with the `+triage` helper for a quick overview:

```bash
gws gmail +triage --max 50 --format json
```

This returns a summary of unread messages (sender, subject, date). Use this to get an initial picture and count.

For a full list of all unread inbox message IDs (needed for batch operations), use:

```bash
gws gmail users messages list --params '{"q":"is:unread in:inbox","maxResults":500,"userId":"me"}' --page-all
```

Report the total count to the user before proceeding. If the count is zero, inform the user their inbox is clean and stop.

### Phase 2 — Categorize

Fetch message metadata in batches of 50 using `users messages get` with `format: "metadata"` and `metadataHeaders` including From, To, Subject, List-Unsubscribe, X-Mailer, and similar headers.

Apply the categorization heuristics defined in `references/triage-heuristics.md`. For each message, assign it to one of three buckets:

- **Keep** — Messages that likely require the user's attention (direct human correspondence, action items, time-sensitive content).
- **Archive** — Messages that are safe to remove from the inbox (automated notifications, marketing, social media digests, CI/CD alerts, newsletters the user has not engaged with).
- **Unsure** — Messages that do not clearly fit either category. Present these to the user for manual classification.

### Phase 3 — Display and Act

Present a grouped summary to the user:

- **Keep**: Show sender and subject for each message.
- **Archive**: Group by category (e.g., "Marketing (12)", "CI Notifications (8)") with representative examples.
- **Unsure**: Show sender and subject, and ask the user to classify each as Keep or Archive.

Wait for explicit user confirmation before taking any action. Do not archive automatically.

Once confirmed, batch-archive using `batchModify` in chunks of 1000 message IDs:

```bash
gws gmail users messages batchModify --params '{"ids":["MSG_ID_1","MSG_ID_2",...],"userId":"me","removeLabelIds":["INBOX"]}'
```

Only remove the `INBOX` label. Do NOT remove the `UNREAD` label — the user may want to read archived messages later.

Refer to `references/triage-heuristics.md` for the full decision table, batch processing details, and output format specification.

---

## 4. Composing Email (Send / Reply / Forward)

### Send a new message

```bash
gws gmail +send --to EMAIL --subject "..." --body "..." [--draft] [--dry-run]
```

Use `--cc` and `--bcc` flags when the user specifies additional recipients. Use `--html` when the message contains HTML formatting.

### Reply to a message

```bash
gws gmail +reply --message-id MSG_ID --body "..."
```

This automatically threads the reply under the original conversation. For reply-all behavior, add `--reply-all`.

### Forward a message

```bash
gws gmail +forward --message-id MSG_ID --to EMAIL
```

Add `--body "..."` to include a note above the forwarded content.

### Mandatory preview rule

ALWAYS show the composed message to the user before sending. Display the full draft including recipients, subject line, and body text. Use the `--dry-run` flag when available to generate the preview without sending.

Do not send until the user explicitly confirms. If the user requests changes, revise and show the updated draft before sending.

For messages the user wants to save without sending, use the `--draft` flag to store the message as a draft in Gmail.

---

## 5. Search and Read

### Search for messages

```bash
gws gmail users messages list --params '{"q":"QUERY","userId":"me"}'
```

The `q` parameter accepts full Gmail search syntax. Common operators include:

- `from:sender@example.com` — filter by sender
- `to:recipient@example.com` — filter by recipient
- `subject:keyword` — filter by subject line
- `after:2026/01/01 before:2026/03/01` — date range
- `has:attachment` — messages with attachments
- `is:unread` — unread messages only
- `label:LABEL_NAME` — messages with a specific label

Combine operators freely: `from:alice@example.com subject:report after:2026/03/01 has:attachment`.

Refer to `references/gws-gmail-commands.md` for the full query syntax cheat sheet and additional parameters.

### Read a specific message

```bash
gws gmail +read --id MSG_ID
```

This retrieves and displays the full message content including headers, body, and attachment metadata. Only invoke this when the user specifically asks to read a message — do not fetch message bodies during triage or search unless instructed.

---

## 6. Label and Archive Operations

### List all labels

```bash
gws gmail users labels list --params '{"userId":"me"}'
```

Cache the label list during a session to avoid repeated API calls. Labels have both a human-readable `name` and an internal `id` — always use the `id` when modifying messages.

### Archive a single message

```bash
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","removeLabelIds":["INBOX"]}'
```

### Bulk archive

```bash
gws gmail users messages batchModify --params '{"ids":["MSG_ID_1","MSG_ID_2",...],"userId":"me","removeLabelIds":["INBOX"]}'
```

Chunk into batches of 1000 IDs if the list exceeds that limit.

### Apply a label

```bash
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","addLabelIds":["LABEL_ID"]}'
```

For bulk labeling, use `batchModify` with `addLabelIds`.

### Remove a label

```bash
gws gmail users messages modify --params '{"id":"MSG_ID","userId":"me","removeLabelIds":["LABEL_ID"]}'
```

### Create a new label

```bash
gws gmail users labels create --params '{"userId":"me","name":"New Label"}'
```

---

## 7. Interactive Selection UX

When presenting lists of emails (search results, triage unsure pile, inbox messages), always use numbered lists so the user can select by number instead of typing email subjects or IDs.

### Numbered list format

```
 1. alice@company.com — Q2 planning doc review
 2. bob@client.com — Re: contract questions
 3. notifications@github.com — [email-tools] New issue #12
 4. newsletter@substack.com — Weekly AI digest
```

### Selection prompt

After showing a numbered list, ask the user to pick using numbers:

```
Which email(s)? (e.g., 1  or  1,3,5  or  1-5  or  all)
```

### Selection parsing

- Single number: `3` → act on item 3
- Comma-separated: `1,3,5` → act on items 1, 3, and 5
- Range: `1-5` → act on items 1 through 5
- `all` → act on all listed items
- `none` or `skip` → skip, take no action

### When to use numbered selection

- **Triage unsure pile** — Present unsure emails numbered, ask which to keep vs archive
- **Search results** — After searching, show numbered results, ask which to read/reply/forward/archive
- **Reply/Forward** — If user says "reply to Bob" and there are multiple threads from Bob, show numbered list to disambiguate
- **Delete confirmation** — Show numbered list of messages about to be deleted

### Internal tracking

Maintain a mapping of display number → message ID for the current list. When the user selects by number, resolve to the actual message ID before executing the gws command. Reset numbering when presenting a new list.

---

## 8. Safety Rules

Follow these rules without exception. They override any user shortcut requests.

- **NEVER send email without showing the user a preview first.** Always display the full draft (recipients, subject, body) and wait for explicit confirmation.
- **NEVER delete messages without explicit confirmation.** Prefer archiving over deleting. If the user asks to delete, show the count and a sample of messages that will be affected, then wait for a clear "yes" or equivalent.
- **NEVER read email body content unless the user specifically asks to read a message.** During triage and search, use only metadata (sender, subject, date, labels). Do not fetch or display message bodies without an explicit request.
- **Always show what will happen before doing it.** State the count of messages, the action to be taken, and which labels will be added or removed.
- **Abort immediately if the user says "stop" or "cancel."** Halt the current operation, report what was completed and what was not, and await further instructions.
- **During triage, only remove the INBOX label.** Do NOT remove the UNREAD label. Do NOT add any labels unless the user requests it. Archive means "remove from inbox" — nothing more.
- **Never modify or delete labels without confirmation.** Deleting a label is irreversible and affects all messages carrying that label.
- **Treat "send" as irreversible.** Once sent, a message cannot be recalled. This is why the preview step is mandatory.

---

## 9. Reference Files

Two reference documents provide detailed specifications that supplement this skill file:

- **`references/setup-guide.md`** — Complete first-time setup walkthrough: gws installation, Google Cloud project creation, OAuth consent screen, client secret download, per-account login, adding test users, troubleshooting common errors.
- **`references/gws-gmail-commands.md`** — Full gws Gmail command reference including syntax for every supported operation, parameter schemas, pagination options, error handling patterns, and worked examples for common workflows.
- **`references/triage-heuristics.md`** — Categorization decision table with header-matching rules, sender pattern heuristics, batch processing strategy, output format specification, and edge case handling (e.g., mailing lists the user participates in, transactional emails that might be important, calendar notifications).

Consult these references when executing any non-trivial operation. They contain the authoritative details for command syntax and triage logic.
