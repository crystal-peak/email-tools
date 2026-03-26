# Email Triage Heuristics

Categorize Gmail messages using only email metadata headers. Do not fetch or inspect full message bodies.

## Headers to Request

Fetch these metadata headers for every message:

| Header | What it reveals |
|--------|-----------------|
| `From` | Sender address and display name |
| `To` | Direct recipients — indicates whether the user is a primary addressee |
| `Cc` | Carbon-copy recipients — indicates passive inclusion |
| `Subject` | Topic line, thread indicators (`Re:`), and action-required keywords |
| `List-Unsubscribe` | Present on newsletters and mailing lists |
| `X-GitHub-Sender` | Present on GitHub notification emails |
| `X-Jira-FingerPrint` | Present on Jira notification emails |
| `Reply-To` | Often differs from `From` on automated/marketing mail |
| `Content-Type` | Detects calendar invites (`text/calendar`, `application/ics`) |
| `Precedence` | Value `bulk` indicates mass-sent mail |
| `X-Auto-Response-Suppress` | Present on automated/out-of-office messages |
| `X-Mailer` | Identifies the sending software or service |
| `Sender` | Envelope sender, useful when `From` is spoofed or aliased |

Fetch command:

```
gws gmail users.messages get --params '{"id":"MSG_ID","userId":"me","format":"metadata","metadataHeaders":["From","To","Cc","Subject","List-Unsubscribe","X-GitHub-Sender","X-Jira-FingerPrint","Reply-To","Content-Type","Precedence","X-Auto-Response-Suppress","X-Mailer","Sender"]}'
```

Obtain the user's own email address from `gws gmail users.getProfile` before evaluating any rules.

## Categorization Rules

Apply rules in order. First match wins.

### Keep (Important)

| Signal | How to detect | Confidence |
|--------|---------------|------------|
| Direct human email, user in To | No `List-Unsubscribe` header, user's email in `To:` (not just CC), no `Precedence: bulk`, no `X-Auto-Response-Suppress` | High |
| Reply in a thread user participates in | Subject starts with `Re:`, user in `To:` | High |
| Same organization domain | Sender domain matches user's authenticated domain | High |
| Calendar invite or meeting | `Content-Type` contains `text/calendar` or `application/ics` | High |
| Action-required signals | Subject contains any of: "action required", "please review", "approval needed", "sign by", "expiring", "deadline", "urgent", "your input needed" (case-insensitive) | Medium |
| Known VIP senders | User-specified list (future enhancement) | High |

### Archive (Noise)

| Signal | How to detect | Confidence |
|--------|---------------|------------|
| Newsletter or mailing list | Has `List-Unsubscribe` header | High |
| GitHub notification | `From` contains `notifications@github.com` OR `X-GitHub-Sender` header present | High |
| Jira notification | `X-Jira-FingerPrint` header present OR `From` contains `jira@` | High |
| Slack notification | `From` contains `@slack.com` or `@email.slack.com` | High |
| AWS notification | `From` contains `@amazonaws.com` or `@aws.amazon.com` | High |
| CI/CD or automated | `From` contains `noreply@`, `no-reply@`, or `donotreply@` combined with automated service patterns | Medium |
| Marketing or promotional | `Precedence: bulk` header, or known marketing sender domains | Medium |
| Social media | `From` domain is `facebookmail.com`, `x.com`, `twitter.com`, `linkedin.com`, `instagram.com`, or `pinterest.com` | High |
| Large CC thread, user only CC'd | User in `Cc:` but NOT in `To:`, and CC list has 3+ recipients | Medium |

### Unsure

Assign everything that does not match a Keep or Archive rule to the Unsure bucket. Present these to the user for manual decision.

## Batch Processing Strategy

- **Header fetching**: Process in batches of 50 message IDs to avoid terminal overflow.
- **Batch modify**: Send a maximum of 1000 IDs per `batchModify` call. Chunk into multiple calls if the total exceeds 1000.
- **Rate limiting**: If `gws` returns a rate limit error, add a 2-second pause between batches.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty inbox | Print "Inbox is clean! No unread messages." and stop. |
| All Keep | Print "All N messages look important. Nothing to archive." and stop. |
| All Archive | Print "All N messages look like noise. Archive all?" and wait for confirmation. |
| `gws` command failure | Show the error, suggest checking auth status, do not retry automatically. |
| Very large inbox (1000+ messages) | Process in waves, show a running total after each wave. |
| User in both To and CC | Treat as To. Keep takes priority. |
| Thread with mixed signals (e.g., a human reply to a newsletter) | Assign to Unsure. |

## Output Format

Present results in this structure:

```
## Inbox Triage Results

**Found N unread messages**

### Keep (X messages)
| From | Subject |
|------|---------|
| ... | ... |

### Archive (Y messages)
**Newsletters (N):** sender1, sender2...
**GitHub (N):** repo1, repo2...
**Slack (N):** channel digests
**Marketing (N):** sender1, sender2...
**Other automated (N):** ...

### Unsure (Z messages)
| # | From | Subject |
|---|------|---------|
| 1 | ... | ... |
| 2 | ... | ... |

**Ready to archive Y messages?** (yes to proceed, or adjust Unsure items first)
```

## Safety Constraints

- ONLY remove the `INBOX` label when archiving. Do NOT remove `UNREAD` -- the user may want to read archived items later.
- NEVER permanently delete messages during triage.
- ALWAYS show the summary and get an explicit "yes" before archiving anything.
- If the user says "stop" or "cancel", abort immediately.
- Report the exact count of messages archived after completion.
