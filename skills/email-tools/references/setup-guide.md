# Setup Guide

Walk users through the complete gws CLI setup. This is a one-time process per machine, plus a quick step per Gmail account.

## Quick Diagnosis

Run these checks in order to determine what state the user is in:

```bash
which gws 2>/dev/null
```

- **Not found** → Go to Step 1 (Install)
- **Found** → Check auth:

```bash
gws auth status 2>&1
```

- `"auth_method": "none"` or `"has_refresh_token": false` → Go to Step 2 (Google Cloud project) or Step 3 (Login) depending on whether `client_config_exists` is true
- `"token_valid": true` → Fully set up. Verify with a profile fetch:

```bash
gws gmail users getProfile --params '{"userId":"me"}'
```

## Step 1: Install gws

```bash
npm install -g @googleworkspace/cli
```

Alternative methods:
- Homebrew: `brew install googleworkspace-cli`
- From source: see https://github.com/googleworkspace/cli

Verify: `which gws` should return a path.

## Step 2: Google Cloud Project + OAuth Credentials

This is the most involved step. Guide the user through it carefully.

### 2a. Create a Google Cloud project

Direct the user to: https://console.cloud.google.com/projectcreate

- Project name: anything (e.g., "email-tools" or "gws-cli")
- Organization: leave as default or pick their org
- Click "Create" and wait for it to provision

### 2b. Enable the Gmail API

Direct the user to: https://console.cloud.google.com/apis/library/gmail.googleapis.com

- Make sure the correct project is selected in the top dropdown
- Click "Enable"

### 2c. Configure OAuth consent screen

Direct the user to: https://console.cloud.google.com/auth/audience

- **User type**: "External" (works for any Gmail account). Use "Internal" only if they have Google Workspace admin access and want org-only access.
- **App name**: anything (e.g., "email-tools")
- **User support email**: their email
- **Developer contact email**: their email
- Skip the scopes page — gws handles scope selection at login time
- **Test users**: Add every Gmail address they want to use with this tool. This is critical — while the app is in "Testing" mode, only emails added here can authenticate. They can add more later.

### 2d. Create OAuth client ID

Direct the user to: https://console.cloud.google.com/apis/credentials

- Click "Create Credentials" → "OAuth client ID"
- Application type: **Desktop app**
- Name: anything (e.g., "gws-cli")
- Click "Create"
- **Download the JSON file** — click the download button

### 2e. Place the client secret file

The downloaded file will be named something like "Client Secret JSON from Google Cloud.json" or "client_secret_NUMBERS.json". It needs to go to a specific location:

```bash
mkdir -p ~/.config/gws
```

Then ask the user where they downloaded the file. Common locations:

```bash
# Check Downloads folder for the file
ls -t ~/Downloads/*.json | head -5
```

Copy it to the right place:

```bash
cp "PATH_TO_DOWNLOADED_FILE" ~/.config/gws/client_secret.json
```

Verify:

```bash
ls ~/.config/gws/client_secret.json
```

## Step 3: Authenticate (per account)

This step must be run interactively — it opens a browser. Instruct the user to run:

```
! gws auth login -s gmail
```

The `!` prefix is required in Claude Code to run interactive commands.

### What happens in the browser

1. **Scope selection** — The terminal shows a list of OAuth scopes. Select both Gmail and Cloud Platform. Press Enter.
2. **Google sign-in** — Browser opens to Google's OAuth consent page. Pick the Gmail account to authorize.
3. **"Access blocked" error** — If this appears, the email hasn't been added as a test user. Go back to the consent screen (https://console.cloud.google.com/auth/audience), add the email under "Test users", then retry.
4. **Permission grant** — Check "Select all" to grant both permissions, then click "Continue".
5. **Success** — Terminal shows `"status": "success"` with the authenticated email.

### Verify

```bash
gws gmail users getProfile --params '{"userId":"me"}'
```

Should return the email address and message counts.

## Adding More Accounts

The gws CLI stores one set of credentials at a time. To add/switch accounts:

1. **Add the email as a test user** in Google Cloud Console (https://console.cloud.google.com/auth/audience) — under "Test users", click "Add users"
2. **Re-authenticate**: `! gws auth login -s gmail` — pick the new account in the browser
3. This overwrites the previous credentials. Only one account is active at a time.

To check which account is currently active:

```bash
gws auth status 2>&1 | grep '"user"'
```

## Troubleshooting

### "gcloud CLI not found" on `gws auth setup`

The `gws auth setup` shortcut requires gcloud. Skip it entirely — the manual OAuth route (Step 2) works without gcloud.

### "Access blocked: has not completed the Google verification process"

The email needs to be added as a test user. Go to https://console.cloud.google.com/auth/audience → "Test users" → "Add users" → add the email → retry login.

### "Required path parameter userId is missing"

All Gmail API methods require `--params '{"userId":"me"}'`. The helper commands (+triage, +send, etc.) handle this automatically, but raw API methods need it explicitly.

### Auth works but Gmail commands fail with permission errors

The auth scopes may not include Gmail. Re-login with Gmail scope:

```
! gws auth login -s gmail
```

### Python errors when installing gcloud via brew

Skip gcloud entirely. The manual OAuth setup (Step 2) doesn't need it.
