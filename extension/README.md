# Drift — Read Later (browser extension)

A minimal Manifest V3 extension that saves the page in the current tab to your
[Drift](../) reading list. Works in Chrome, Edge, and other Chromium browsers
(and, with minor packaging, Firefox).

## How it works

Clicking the toolbar button sends the active tab's URL and title to Drift's
`POST /api/saved_items` endpoint, authenticated with a personal API token. Drift
stores it immediately and fetches the page server-side to fill in the title,
excerpt, site name, and lead image. The icon briefly shows `✓` on success or `!`
on failure.

## Setup

1. In Drift, go to **Account → Browser extension** and generate an API token.
   Copy it — the full value is shown only once.
2. Load the extension:
   - Open `chrome://extensions`
   - Enable **Developer mode**
   - Click **Load unpacked** and select this `extension/` folder
3. Open the extension's **Options** (or click the icon once — it opens
   automatically until configured) and enter:
   - **Server URL** — your Drift address, e.g. `https://drift.example.com`
   - **API token** — the token from step 1
   Saving prompts for permission to reach that server; this is required so the
   background request isn't blocked by CORS.

## Usage

Click the toolbar icon on any page to save it. Open Drift → **Read later** to
read or archive saved pages.

## Permissions

- `activeTab` — read the URL/title of the tab you're on, only when you click.
- `storage` — remember your server URL and token.
- optional host access — granted per-server when you save settings, so the
  extension can talk only to the Drift install you configured.
