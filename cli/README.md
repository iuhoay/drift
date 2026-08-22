# drift CLI

Command-line client for [Drift](https://rdrift.app). Talks to the live HTTP API — it does not read the local Rails database.

## Install

From the repository root:

```sh
cargo install --path cli
```

Sign in through the browser (GitHub, Google, or password). The CLI never asks you to paste a token:

```sh
drift auth login
```

Default host is `https://rdrift.app`. After you click **Authorize CLI**, a one-time code is handed back to the local listener and exchanged for an API token stored in `$XDG_CONFIG_HOME/drift/config.toml` (or `~/.config/drift/config.toml`) with mode `0600`.

Non-interactive override: `drift auth login --token <token>` (the flag is hidden from `--help`).

## Commands

| Command | What it does |
| --- | --- |
| `drift auth login` | Open a browser, sign in, store a token |
| `drift auth status` | Show host, masked token, and whether the API accepts it |
| `drift feeds` | List subscribed feeds |
| `drift inbox [--feed ID] [--limit N]` | Unread entries (server default 20, max 50) |
| `drift search <query> [--limit N]` | Search entries |
| `drift show <id>` | Print one entry's `body` from the API |

There is no mark-read, star, or saved-items command in v1.

## Global flags

| Flag | Meaning |
| --- | --- |
| `--output json\|text` | Default is one line of raw JSON; `text` is the human table |
| `--host <url>` | Override the API host |
| `--token <token>` | Override the bearer token (hidden from `--help`) |

`--output json` prints one raw JSON object (what an agent should parse).

## Environment

Highest wins: flag → env → config file.

| Variable | Meaning |
| --- | --- |
| `DRIFT_HOST` | API base URL (trailing slash stripped) |
| `DRIFT_TOKEN` | Bearer token |

Config file:

```toml
host = "https://rdrift.app"
token = "..."
```

## Agent skill

A skill for coding agents lives at [`../skills/drift-cli`](../skills/drift-cli). Symlink that directory into `~/.pi/agent/skills/` or `~/.agents/skills/`.
