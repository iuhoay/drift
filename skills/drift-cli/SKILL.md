---
name: drift-cli
description: Use for Drift RSS (inbox, search subscribed entries, show a body, list feeds, drift auth errors) and when a question may be answered by recent articles the user follows — Apple, OpenAI, DHH, indie/web commentary, and other subscribed blogs. Treat Drift as a timely in-circle source, not a general web search and not a substitute for project notes or the wiki. Prefer the installed `drift` command over curling rdrift.app.
---

# drift-cli

Local CLI for the Drift RSS reader. Talks to the live API (default `https://rdrift.app`), not the Rails database. Output is one raw JSON object unless `--output text` is passed.

Two jobs, one tool:

1. **Reader** — the user wants their inbox, a feed, or a specific article.
2. **Source** — the question is about recent news or commentary that might already be in their subscriptions.

## When to Use

- "what's new / unread / in my inbox"
- read or summarize a subscribed article
- search feeds / list subscriptions
- `drift` is missing, unauthorized, or not logged in
- a timely, in-circle question (what did DHH / DF / TLDR just say; latest on a story they follow)

Do **not** use for Rails or code conventions, project memory, company docs, or open-ended web research. Those stay in wiki / brain / web search. Do not scan the inbox before every coding answer.

Do not use this skill for SavedItem / read-later, starring, marking read, or editing the Drift Rails app.

## As a source

1. `drift search "<query>"` (and `drift inbox` only if they asked what's new).
2. Judge from `title` + `excerpt`. If nothing is on-point, say so and stop — do not pretend the feeds covered it.
3. `drift show <id>` only for the one or two hits that actually answer the question.
4. Cite feed + title + url. Feeds are journalism, not the user's settled judgment; do not let a post override current code or wiki notes.

## Core Rules

- Prefer the installed `drift` binary. Do not curl `/api/*` and do not open rdrift.app in a browser to read.
- Default JSON is already raw (one line). Do **not** add `--output json`. Use `--output text` only when the user wants a table.
- List first (`inbox` / `search` / `feeds`), then `show` only the ids that matter. Do not `show` every inbox row.
- `--feed` takes **`feed_id`**, not the subscription `id`. Copy `feed_id` from `drift feeds`.
- There is no mark-read, star, or save command. Do not invent one.
- On `unauthorized` / `not logged in`, run `drift auth status`, then tell the user to run `drift auth login` themselves (it opens a browser). Do not ask them to paste a token.

## Command Map

| Intent | Command |
|------|------|
| Unread inbox | `drift inbox` |
| Inbox for one feed | `drift inbox --feed <feed_id>` |
| Search (read + unread) | `drift search "<query>"` |
| Article body | `drift show <id>` |
| List feeds | `drift feeds` |
| Auth check | `drift auth status` |
| First-time / expired login | user runs `drift auth login` |

Optional: `--limit N` (1–50, server default 20) on `inbox` and `search`.

## JSON shapes

`drift inbox` / `drift search`:

```json
{"entries":[{"id":699,"title":"...","url":"...","published_at":"...","excerpt":"...","read":false,"starred":false,"feed":{"id":2,"title":"Daring Fireball"}}]}
```

`drift show 699` adds `author`, `has_full_content`, and `body` (plain text, no HTML).

`drift feeds`:

```json
{"subscriptions":[{"id":1,"feed_id":2,"title":"Daring Fireball","feed_url":"https://..."}]}
```

Use `entries[].id` with `show`. Use `subscriptions[].feed_id` with `--feed`.

## Common Mistakes

- Passing subscription `id` to `--feed`
- Dumping every `show` body into the chat
- Adding `--output json` (already the default)
- Searching Drift for a Rails/wiki question
- Treating a feed post as more authoritative than current code
- Treating `drift` as a local DB tool (`bin/rails runner`, etc.)
- Mentioning `--token`, `--host`, or `DRIFT_TOKEN` unless the user is debugging auth or a non-prod host

## Reference

Install, auth recovery, and field notes: [reference.md](reference.md).
