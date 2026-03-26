# Setup Guide

Walk users through the complete gws CLI setup. This is a one-time process per machine, plus a quick step per Gmail account.

## Quick Diagnosis

Run these checks in order to determine what state the user is in:

```bash
which gws 2>/dev/null && gws auth status 2>&1
```

- **gws not found** → Start at Step 1
- **`auth_method: none`** or **`client_config_exists: false`** → Start at Step 2
- **`has_refresh_token: false`** or **`token_valid: false`** → Start at Step 4
- **`token_valid: true`** → Fully set up. Verify with `gws gmail users getProfile --params '{"userId":"me"}'`

## Step 1: Install gws

```bash
npm install -g @googleworkspace/cli
```

Alternative methods:
- Homebrew: `brew install googleworkspace-cli`
- From source: see https://github.com/googleworkspace/cli

Verify: `which gws` should return a path.

## Step 2: Collect Gmail Accounts

Before starting the Google Cloud setup, ask the user which Gmail accounts they want to manage. This determines how many test users to add in the OAuth consent screen — much easier to do all at once.

Ask: "Which Gmail addresses do you want to manage? List all of them — personal, work, etc."

Present as a numbered list for confirmation:
```
Got it. I'll make sure all of these are set up:
 1. alice@acme.com
 2. alice.jones@gmail.com
 3. alice@freelance.dev

Let's get the Google Cloud project configured.
```

Store this list for Step 3c (test users) and Step 4 (per-account login).

## Step 3: Google Cloud Project + OAuth Credentials

This is the most involved step. Guide the user through it one sub-step at a time — confirm each is done before moving to the next.

### 3a. Create a Google Cloud project

Direct the user to: https://console.cloud.google.com/projectcreate

- Project name: anything (e.g., "email-tools" or "gws-cli")
- Organization: leave as default or pick their org
- Click "Create" and wait for it to provision

### 3b. Enable the Gmail API

Direct the user to: https://console.cloud.google.com/apis/library/gmail.googleapis.com

- Make sure the correct project is selected in the top dropdown
- Click "Enable"

### 3c. Configure OAuth consent screen

Direct the user to: https://console.cloud.google.com/auth/audience

- **User type**: "External" (works for any Gmail account). Use "Internal" only if they have Google Workspace admin access and want org-only access.
- **App name**: anything (e.g., "email-tools")
- **User support email**: their email
- **Developer contact email**: their email
- Skip the scopes page — gws handles scope selection at login time
- **Test users**: Add ALL the Gmail addresses collected in Step 2. This is critical — while the app is in "Testing" mode, only emails listed here can authenticate. Present the list from Step 2 and remind the user to add every one.

### 3d. Create OAuth client ID

Direct the user to: https://console.cloud.google.com/apis/credentials

- Click "Create Credentials" → "OAuth client ID"
- Application type: **Desktop app**
- Name: anything (e.g., "gws-cli")
- Click "Create"
- **Download the JSON file** — click the download button

### 3e. Place the client secret file

The downloaded file may have an unusual name (e.g., "Client Secret JSON from Google Cloud.json"). Find it and move it into place:

```bash
mkdir -p ~/.config/gws
```

Search for the downloaded file:

```bash
ls -t ~/Downloads/*.json | head -5
```

Copy it (use the actual filename found above):

```bash
cp "PATH_TO_DOWNLOADED_FILE" ~/.config/gws/client_secret.json
```

Verify it's in place:

```bash
ls ~/.config/gws/client_secret.json
```

## Step 4: Authenticate (per account)

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

### Multiple accounts

The gws CLI stores one active account at a time. After authenticating the first account, let the user know:

"You're connected as alice@acme.com. To switch to another account later, just run `! gws auth login -s gmail` again and pick a different one. All your accounts are already approved as test users, so switching is instant."

There is no need to authenticate every account right now — they can switch whenever they want. But if the user wants to verify a specific account works, repeat the login step for each one.

## Switching Accounts (Post-Setup)

To check which account is currently active:

```bash
gws auth status 2>&1 | grep '"user"'
```

To switch:

```
! gws auth login -s gmail
```

Pick the desired account in the browser. The new credentials replace the old ones. All accounts added as test users during setup will work without any additional configuration.

## Troubleshooting

### "gcloud CLI not found" on `gws auth setup`

The `gws auth setup` shortcut requires gcloud. Skip it entirely — the manual OAuth route (Step 3) works without gcloud.

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

Skip gcloud entirely. The manual OAuth setup (Step 3) doesn't need it.
