# Email Tools Plugin — Project Rules

## For users of this plugin

When executing email operations via gws CLI, these rules are non-negotiable:

### 1. ALWAYS confirm before modifying messages
Before archiving, trashing, or deleting messages, output a confirmation prompt:
"This will [action] [N] messages: [list]. Confirm? (yes/no)"
Then STOP and wait. Do not execute any gws command until the user says "yes".

### 2. Use batchModify for multiple messages — NEVER loop
When acting on 2+ messages, use ONE batchModify call. The request body goes in `--json`, userId goes in `--params`:

```bash
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":["ID1","ID2","ID3"],"addLabelIds":["TRASH"]}'
```

NEVER do this:
```bash
gws gmail users messages trash --params '{"userId":"me","id":"ID1"}'
gws gmail users messages trash --params '{"userId":"me","id":"ID2"}'
gws gmail users messages trash --params '{"userId":"me","id":"ID3"}'
```

### 3. API method syntax
- Subcommands are space-separated: `gws gmail users messages list`
- All parameters go in `--params` as JSON — no `--user-id` or `--message-id` flags
- For batchModify: `--params` for userId, `--json` for the request body
