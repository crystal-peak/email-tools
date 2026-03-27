# Multi-Account Management

The gws CLI stores one credential set per config directory. To support multiple Gmail accounts simultaneously, email-tools uses separate config directories per account and a state file to track them.

## State File

Account state is stored at `~/.config/email-tools/accounts.json`:

```json
{
  "accounts": [
    {
      "email": "dan.wagner06@gmail.com",
      "label": "personal",
      "config_dir": "~/.config/gws-personal"
    },
    {
      "email": "dan@moneygameventures.com",
      "label": "work",
      "config_dir": "~/.config/gws-work"
    }
  ],
  "active": "dan.wagner06@gmail.com"
}
```

## Reading the State File

At the start of every email session, check if the state file exists:

```bash
cat ~/.config/email-tools/accounts.json 2>/dev/null
```

- **File exists with accounts** → Show active account, proceed
- **File doesn't exist** → First-time setup, follow the Add Account flow

## Adding an Account

When the user wants to add an account (first-time setup or "add account"):

1. Ask for a short label (e.g., "personal", "work", "freelance")
2. Create a config dir for it:
   ```bash
   mkdir -p ~/.config/gws-LABEL
   ```
3. Copy the client_secret.json from the default config (all accounts share the same OAuth app):
   ```bash
   cp ~/.config/gws/client_secret.json ~/.config/gws-LABEL/client_secret.json
   ```
4. Tell the user to authenticate interactively:
   ```
   ! GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-LABEL gws auth login -s gmail
   ```
5. After auth succeeds, verify by fetching the profile:
   ```bash
   GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-LABEL gws gmail users getProfile --params '{"userId":"me"}'
   ```
6. Extract the email address from the response
7. Update the state file with the new account (read → add → write)
8. Set as active if it's the first account or if the user requests it

## Switching Accounts

When the user says "switch account", "use my work email", "check personal", etc.:

1. Read the state file
2. Show numbered list of accounts:
   ```
   Gmail Accounts:
    1. dan.wagner06@gmail.com (personal) ← active
    2. dan@moneygameventures.com (work)

   Switch to? (1-2)
   ```
3. Update `active` in the state file
4. Confirm: "Switched to dan@moneygameventures.com (work)"

No re-authentication needed — each account has its own persistent credentials.

## Using the Active Account

All gws commands must be prefixed with the active account's config dir. Before running any gws command:

1. Read the state file to get the active account's `config_dir`
2. Prefix the command:
   ```bash
   GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws-LABEL gws gmail +triage --format json
   ```

Helper function pattern for the prefix:
```bash
GOOGLE_WORKSPACE_CLI_CONFIG_DIR=CONFIG_DIR gws gmail ...
```

Replace `CONFIG_DIR` with the `config_dir` value from the active account in the state file.

## Removing an Account

When the user says "remove account":

1. Show numbered list
2. After selection, remove from state file
3. Optionally delete the config dir:
   ```bash
   rm -r ~/.config/gws-LABEL
   ```
4. If the removed account was active, set the first remaining account as active

## First-Time Setup Flow

If no state file exists and no default gws auth exists:

1. Follow `references/setup-guide.md` for Google Cloud project + OAuth setup
2. Ask: "Which Gmail addresses do you want to manage?"
3. For each address:
   - Ask for a label
   - Create config dir
   - Copy client_secret.json
   - Auth interactively
   - Verify profile
4. Write the state file with all accounts
5. Set the first account as active

If a default gws auth already exists (migrating from single account):

1. Read the current auth: `gws auth status`
2. Get the email from the profile
3. Ask for a label for this existing account
4. Move or copy the existing config: `cp -r ~/.config/gws ~/.config/gws-LABEL`
5. Write the state file
6. Ask if they want to add more accounts
