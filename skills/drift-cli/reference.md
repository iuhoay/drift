# drift-cli reference

Companion to `SKILL.md`. Source of truth lives in the Drift repo (`skills/drift-cli/`).

## Install

Do **not** clone the repo or run `cargo install`. The user-facing binary comes from GitHub Releases tagged `cli/v*` (not the Kamal `drift@<sha>` deploy tags).

```sh
tag=$(gh release list --repo iuhoay/drift --json tagName --jq '.[] | select(.tagName | startswith("cli/v")) | .tagName' | head -1)
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  asset=drift-aarch64-apple-darwin ;;
  Linux-x86_64)  asset=drift-x86_64-unknown-linux-gnu ;;
  *) echo "no published binary for $(uname -s)-$(uname -m)"; exit 1 ;;
esac
gh release download "$tag" --repo iuhoay/drift --pattern "$asset" --dir .
install -m 0755 "./$asset" "$HOME/.local/bin/drift"
```

`$HOME/.local/bin` must be on `PATH`. If `gh` is missing, point the user at https://github.com/iuhoay/drift/releases and the matching asset — still no source install.

If `drift` is not on `PATH` after that, stop. Do not fall back to curling the API.

## Install the skill

The user does not have this repo. Fetch the two files; do not `git clone` or `ln -s` a checkout.

```sh
dir="$HOME/.pi/agent/skills/drift-cli"   # or $HOME/.agents/skills/drift-cli
mkdir -p "$dir"
curl -fsSL https://raw.githubusercontent.com/iuhoay/drift/main/skills/drift-cli/SKILL.md -o "$dir/SKILL.md"
curl -fsSL https://raw.githubusercontent.com/iuhoay/drift/main/skills/drift-cli/reference.md -o "$dir/reference.md"
```

## Auth

```sh
drift auth login    # opens the browser; user signs in (GitHub / Google / password) and clicks Authorize CLI
drift auth status   # host + masked token + ok/unauthorized
```

`auth login` starts a loopback listener and exchanges a one-time code for an API token. The agent cannot complete the browser step.

Order: install the binary first, then `auth login`. Do not run login when `drift` is missing.

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
