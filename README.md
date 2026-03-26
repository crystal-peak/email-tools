# email-tools

Gmail assistant for Claude Code — triage, send, reply, forward, search, and manage email using the Google Workspace CLI.

## Prerequisites

- [Google Workspace CLI](https://github.com/googleworkspace/cli) installed and authenticated
- Installation: `npm install -g @googleworkspace/cli` (or via Homebrew, Cargo, etc.)
- Auth: `gws auth login -s gmail`

## Install

Two ways:

**Via skills.sh:**
```bash
npx skills add crystal-peak/email-tools
```

**Via Claude Code plugin marketplace:**
```
/install email-tools@crystal-peak
```

## Usage

```
/email                    # Show capabilities menu
/email triage             # Clean up your inbox
/email send               # Compose an email
/email reply              # Reply to a thread
/email forward            # Forward a message
/email search from:boss   # Search your email
```

Or just ask naturally:
- "Clean up my inbox"
- "Send Bob the quarterly report"
- "What emails did I get from the client this week?"
- "Reply to that thread about the deadline"

## What /email triage does

1. Scans your unread inbox
2. Categorizes messages as Keep, Archive, or Unsure using metadata signals (sender patterns, headers, mailing list indicators)
3. Shows a grouped summary
4. Archives noise on your confirmation

Only archives (removes from inbox) — never deletes. Always asks before acting.

## Safety

- Never sends email without showing you a preview first
- Never deletes without explicit confirmation
- Never reads email body unless you ask
- Archive-only during triage (reversible)
- Aborts immediately on "stop" or "cancel"

## License

MIT
