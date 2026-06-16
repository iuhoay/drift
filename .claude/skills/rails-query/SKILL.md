---
name: rails-query
description: >-
  Read-only inspection of PRODUCTION data for the deployed drift app via
  `bin/kamal query` — the kamal alias for Rails 8.2's `rails query` command. Use
  this whenever the user wants to look up, count, check, or investigate real data
  in prod: how many feeds/entries/users, is there a user with a given email,
  what's the most recent entry, why a feed has zero entries, how many Solid Queue
  jobs are failed, top feeds by subscriber count, or any ad-hoc production data
  question — even if they don't say "query" or "kamal". Also for discovering
  production schema, tables, models, and associations, and reading EXPLAIN plans.
  Prefer it over `bin/kamal console`, `bin/kamal dbc`, or a runner script for
  read-only lookups: it cannot mutate the database, returns structured JSON, and
  paginates instead of dumping huge result sets. Do NOT use it to change prod
  data (updates/deletes), edit app code/models/scopes, write migrations or tests,
  run kamal ops (deploy, logs, restart, backups), answer local-dev database
  questions, or build dashboards/BI — those need other tools.
---

# rails-query

Answer production data questions for the drift app using `bin/kamal query`, the
alias defined in `config/deploy.yml`:

```yaml
aliases:
  query: app exec --reuse "bin/rails query"
```

It runs Rails 8.2's `rails query` command inside the already-running production
app container (`--reuse`, so no new container is spun up). `rails query` is new
in Rails 8.2 — if you assume the alias is broken because you don't recognize the
command, that's the mistake this skill exists to prevent. It is real, and it's
the right tool for read-only production lookups.

## Why this, and not console / dbconsole / runner

When someone asks a read-only question about production data, reach for `query`
first. The other tools are heavier and riskier for this job:

- **It cannot write.** The command runs against a read-only connection — the
  `:reading` role if the app defines one, otherwise the writing connection
  wrapped in `while_preventing_writes`. Any write — `update`, `delete_all`,
  `save`, a callback that touches the DB, or an `INSERT`/`UPDATE` via `--sql` —
  raises and the command exits non-zero. You can hand a teammate a `query`
  command without worrying it mutates prod; `console` gives a live shell where a
  stray `.update!` is a real outage.
- **It returns JSON, not a printed object.** Output is machine-readable, so you
  can parse the answer and act on it instead of eyeballing a `#<Feed:0x...>` dump.
- **It paginates.** Results are capped (100 rows by default) and tell you when
  there's more, so a careless `Entry.all` won't stream a million rows over SSH.
- **It's one-shot.** No interactive session lingering in the container.

Caveat worth knowing: the expression is `eval`'d Ruby with full app context
(evaluated exactly once, even if the DB connection then fails). It is read-only
*with respect to the database*, not a sandbox — don't run expressions with
non-DB side effects (HTTP calls, enqueuing jobs, sending mail). DB writes are
blocked; everything else runs.

## The one thing people get wrong

**The expression is an ActiveRecord / Ruby expression by default — NOT SQL.**
Pass `--sql` only when you actually want to write raw SQL.

```bash
bin/kamal query "Feed.failing.count"                  # ActiveRecord (default)
bin/kamal query --sql "SELECT COUNT(*) FROM feeds"    # raw SQL (needs --sql)
```

Passing `"SELECT ..."` without `--sql` will try to evaluate it as Ruby and fail
with a JSON error. Prefer the ActiveRecord form — it goes through the app's own
scopes and associations and is harder to get subtly wrong.

## drift's Feed vocabulary (there is no `active` column)

A teammate will say "active feeds," but drift derives feed health from columns,
not an `active` boolean. The scopes live in `app/models/feed.rb` and the admin
dashboard uses them directly:

- `Feed.alive` → `dead_at IS NULL` (not given up on)
- `Feed.dead` → `dead_at IS NOT NULL` (crossed `DEAD_AFTER_FAILURES` = 10)
- `Feed.failing` → `fetch_failure_count > 0` (≥1 consecutive failure right now;
  a success resets it to 0). Note `failing` **includes** dead feeds, so don't add
  `failing + dead`.
- `Feed.troubled` → failing feeds, worst first, with a `subscribers_count`
- `Feed#healthy?` → `fetch_failure_count.zero?`

"Backed off" isn't a column: it's failing + alive + `next_fetch_at` in the
future. Map "active" to `Feed.alive` (or alive + healthy) and say which you meant.

```bash
bin/kamal query "Feed.count"                                 # total
bin/kamal query "Feed.alive.count"                           # not dead
bin/kamal query "Feed.alive.where(fetch_failure_count: 0).count"   # alive + healthy
bin/kamal query "Feed.failing.count"                         # any current failures (incl. dead)
bin/kamal query "Feed.dead.count"                            # flagged dead
```

## Core usage

```bash
# Scalars / aggregates
bin/kamal query "Entry.where('created_at > ?', 1.day.ago).count"
bin/kamal query "Entry.group(:feed_id).count"

# Relations return rows (paginated). meta.sql shows the SQL that actually ran.
bin/kamal query "Feed.troubled.limit(10)"

# String literals: single-quote them inside the double-quoted expression
bin/kamal query "User.where(email: 'someone@example.com')"

# Raw SQL when you need it
bin/kamal query --sql "SELECT id, title, last_error FROM feeds WHERE dead_at IS NOT NULL"
```

The expression and flags can appear in any order — `bin/kamal query "Entry.all"
--per 20` and `bin/kamal query --per 20 "Entry.all"` are equivalent.

### Return-type shapes (for the default envelope)

The default `{columns, rows, meta}` envelope shapes `rows` from what the
expression evaluates to:

- **Relation** (`Feed.troubled`) → matching rows + columns.
- **Scalar** (`Feed.count` → `42`) → one row, one `result` column.
- **Hash** (`Feed.group(:dead_at).count`) → `key` / `value` rows.
- **Array** (`Feed.pluck(:title)`) → positional `column_0`, `column_1`, … columns.

## Discover structure before querying

When you don't have the schema memorized, ask the command — don't guess column
or association names. These three return their **own** JSON shapes, not the
`{columns, rows, meta}` envelope:

```bash
bin/kamal query schema            # envelope: one column `table_name`, a row per table
bin/kamal query schema feeds      # object: {table, columns:[{name,type,null,default}], indexes, enums, associations}
bin/kamal query models            # array: [{model, table_name, associations:[{type,name,class_name,...}]}]
```

A good flow for an unfamiliar question: `models` or `schema <table>` to learn the
shape, then a targeted expression.

## Reading the JSON output (envelope)

```json
{
  "columns": ["id", "title", "dead_at"],
  "rows": [[1, "Hacker News", null]],
  "meta": {
    "row_count": 1, "query_time_ms": 4.3, "page": 1, "per_page": 100,
    "has_more": false, "sql": "SELECT \"feeds\".* FROM \"feeds\" WHERE ..."
  }
}
```

Two fields earn their keep:

- **`meta.has_more`** — `true` means the result was truncated; page through the
  rest rather than assuming you saw everything.
- **`meta.sql`** — the exact SQL executed, including the `LIMIT`/`OFFSET` the
  command added. Use it to confirm the query did what you intended.

Errors come back as JSON on stderr with a non-zero exit, e.g.
`{"error": "uninitialized constant Fred", "meta": {"query_time_ms": 0}}` — a
clean message, not a stack trace.

## Pagination

Defaults: `--page 1`, `--per 100`. `--per` is clamped to `[1, 10000]` and
`--page` is floored at 1.

```bash
bin/kamal query "Entry.order(created_at: :desc)" --per 25 --page 2
```

For `--sql`, the command appends `LIMIT`/`OFFSET` only if your SQL doesn't
already contain a `LIMIT` — so a `LIMIT` you write yourself is respected as-is.

## Multiple databases (primary / cache / queue / cable)

Production runs separate databases (see `config/database.yml`). The routing rule:

- **ActiveRecord expressions auto-route to their model's database.** Models that
  `connects_to` another database resolve themselves. Solid Queue's models route
  to the `queue` DB (`config/environments/production.rb`:
  `config.solid_queue.connects_to = { database: { writing: :queue } }`), so just
  use the model — no `--db` needed:

  ```bash
  bin/kamal query "SolidQueue::FailedExecution.count"     # failed jobs, auto-routed
  bin/kamal query "SolidQueue::Job.count"
  ```

- **Raw `--sql` always runs against the primary connection** unless you point it
  elsewhere with `--db` (alias `--database`). That's the only time you need it:

  ```bash
  bin/kamal query --db queue --sql "SELECT COUNT(*) FROM solid_queue_failed_executions"
  bin/kamal query --db queue schema     # list the queue DB's tables
  ```

So: prefer the model (it picks the right DB); reach for `--db` only for raw
`--sql` against a non-primary DB, or a database with no model.

## EXPLAIN for slow queries

```bash
bin/kamal query explain "Entry.where(read_at: nil)"
bin/kamal query explain --sql "SELECT * FROM entries WHERE feed_id = 42"
```

Returns the query plan as rows — useful before reaching for an index change.

## Quoting through kamal

The expression is passed as a single shell argument down to the container.
Keep it on one quoting level: double-quote the whole expression, single-quote
any string literals inside it. Passing the expression via stdin (`query -`)
isn't wired through this alias, so always pass it as a quoted argument.
`RAILS_ENV` is already `production` in the container, so `-e` is unnecessary.

**Avoid Ruby brace literals `{ … }` in the expression.** kamal re-quotes the
argument twice on the way down (local shell → SSH → `docker exec`), and inline
hashes or blocks don't survive — the braces and the spaces inside them get
mangled. This bites most often on association conditions. Use a brace-free
string condition instead:

```bash
# Mangled — nested hash literal with { }:
bin/kamal query "User.joins(:subscriptions).where(subscriptions: { feed_id: 8 })"
# Works — string condition, no braces:
bin/kamal query "User.joins(:subscriptions).where('subscriptions.feed_id = 8')"
```

Top-level keyword hashes are fine because they need no braces
(`where(active: true)`, `group(:feed_id)`); it's the `{ }` that breaks. If an
expression genuinely needs braces or both quote types, simplify it or fall back
to `--sql`.

## Quick reference

| Goal | Command |
|------|---------|
| Total / alive / dead feeds | `bin/kamal query "Feed.count"` · `"Feed.alive.count"` · `"Feed.dead.count"` |
| Failing feeds (worst first) | `bin/kamal query "Feed.troubled.limit(20)"` |
| Recent entries | `bin/kamal query "Entry.order(created_at: :desc)" --per 20` |
| Find by attribute | `bin/kamal query "User.where(email: 'x@y.com')"` |
| Group / aggregate | `bin/kamal query "Entry.group(:feed_id).count"` |
| Failed background jobs | `bin/kamal query "SolidQueue::FailedExecution.count"` |
| Raw SQL | `bin/kamal query --sql "SELECT ..."` |
| List tables / table detail | `bin/kamal query schema` · `bin/kamal query schema entries` |
| List models | `bin/kamal query models` |
| Query plan | `bin/kamal query explain "Entry.where(read_at: nil)"` |
| Non-primary DB (raw SQL) | `bin/kamal query --db queue --sql "SELECT ..."` |
