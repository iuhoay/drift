# drift-cli reference

Companion to `SKILL.md`. Source of truth lives in the Drift repo (`skills/drift-cli/`).

## Install

From the Drift repository root:

```sh
cargo install --path cli
```

Binary name: `drift`. Config: `$XDG_CONFIG_HOME/drift/config.toml` or `~/.config/drift/config.toml` (mode `0600`).

If `drift` is not on `PATH`, do not fall back to curling the API.

## Auth

```sh
drift auth login    # opens the browser; user signs in (GitHub / Google / password) and clicks Authorize CLI
drift auth status   # host + masked token + ok/unauthorized
```

`auth login` starts a loopback listener and exchanges a one-time code for an API token. The agent cannot complete the browser step.

Unauthorized after a working install usually means the token was revoked on the Account → API tokens page. The user must `drift auth login` again.

`--host` and `DRIFT_HOST` override the API base (trailing slash stripped). Default is `https://rdrift.app`. Only use these when the user is pointing at a non-prod server.

`--token` / `DRIFT_TOKEN` exist for non-interactive override and are hidden from `--help`. Do not surface them unless asked.

## Commands

| Command | Notes |
|------|------|
| `drift inbox` | Unread subscribed entries, newest first |
| `drift inbox --feed <feed_id>` | Same, one feed |
| `drift inbox --limit N` | 1–50 |
| `drift search "<query>"` | Full-text over subscribed entries (`scope=all`) |
| `drift show <id>` | One entry; 404 if not subscribed |
| `drift feeds` | Subscriptions; `title` is the custom title when set |

No mark-read, unread, star, subscribe, or saved-items commands.

## Inbox vs show

Inbox rows carry `excerpt` only. Full text is `drift show <id>` → `body`. `has_full_content` is true when someone already fetched the scraped copy; the CLI cannot trigger a scrape.

## `--feed` vs subscription id

`drift feeds` returns both:

- `id` — subscription row
- `feed_id` — the feed, what `--feed` expects

Mixing them silently returns the wrong list (or an empty one).
