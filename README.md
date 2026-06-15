# Drift

A calm, fast, distraction-free RSS reader. Server-rendered Rails 8 + Hotwire,
no SPA, no AI summaries, no social features — just feeds.

## Stack

- Ruby 4.0 / Rails 8 (main)
- PostgreSQL (full-text search via `tsvector`)
- Hotwire (Turbo + Stimulus)
- Tailwind CSS v4
- Solid Queue (background jobs + recurring scheduler)
- Feedjira (parsing) + Faraday (HTTP, ETag/If-Modified-Since/redirects)

## Authentication

Built on the Rails 8 `bin/rails generate authentication` flow:

- `User` with `has_secure_password` and `email_address`
- `Session` records (DB-backed) keyed by a signed httponly cookie
- `Authentication` controller concern with `before_action :require_authentication`
  and `allow_unauthenticated_access` for the sign-in / sign-up / password-reset paths
- `Current.user` / `Current.session` for thread-local access
- Generator-shipped password reset emails (`PasswordsController`)
- Drift adds a thin `RegistrationsController` on top for sign-up

## Models

- `User` — `email_address` + `has_secure_password`
- `Session` — per-device login record (Rails 8 generator)
- `Feed` — feed URL, ETag/Last-Modified, last-fetch metadata
- `Subscription` — joins user ↔ feed (custom title)
- `Entry` — feed item with FTS `search_vector`
- `UserEntry` — per-user `read_at` / `starred_at`

## Run it

```bash
# 1. Start Postgres (Docker is the easiest path):
docker compose up -d postgres

# 2. Copy .env.example to .env and fill in your local Postgres creds.
cp .env.example .env

# 3. Install gems and bootstrap the DB:
bundle install
bin/rails db:create db:migrate db:seed

# 4. Start the app + Tailwind watcher + Solid Queue worker:
bin/dev
```

Open http://localhost:3000. Seeded login: `demo@drift.local` / `drift1234`.

### Environment variables

Drift uses Rails 8.2's built-in `.env` support (no `dotenv-rails` gem). Values
in `.env` are read via `Rails.application.dotenvs` and combined into
`Rails.app.creds` alongside real `ENV` and `config/credentials.yml.enc`. The
`.env` file is **not** loaded into `ENV` automatically — config files look up
values explicitly:

```erb
username: <%%= Rails.application.creds.option(:database_username) %>
```

In production, set the same keys as real environment variables (they take
precedence over `.env`).

### Production domain

Set `APP_HOST` to the canonical public domain before booting production. Rails
uses it for absolute URLs, including password reset emails, and Kamal uses it
for the proxy host.

```bash
APP_HOST=rdrift.app
APP_HOSTS=rdrift.app,www.rdrift.app # optional aliases
APP_PROTOCOL=https
```

If Kamal terminates TLS through its proxy, keep the default `FORCE_SSL=true` and
point DNS at the server before deploying so Let's Encrypt can issue the
certificate. For local production-style Docker compose, `FORCE_SSL=false` is set
with `APP_HOST=drift.local`.

### Sending email

Drift sends one transactional email — the password-reset link — delivered
asynchronously through Solid Queue. Production reads SMTP settings entirely from
the environment (on ONCE these come from the host's mail settings UI):

```bash
SMTP_ADDRESS=smtp.example.com      # required to enable delivery
SMTP_PORT=587                      # optional, defaults to 587
SMTP_USERNAME=...                  # optional
SMTP_PASSWORD=...                  # optional
SMTP_AUTHENTICATION=plain          # optional, defaults to plain
MAILER_FROM_ADDRESS="Drift <no-reply@example.com>"
```

Until `SMTP_ADDRESS` is set, mail delivery stays **off** — the app boots fine and
queued reset emails are dropped rather than retried forever. Bring any SMTP
provider (Postmark, SES, Resend, Fastmail, …); no provider gem is required.

## Background jobs

Solid Queue runs in-process via `bin/jobs` (started by `bin/dev`).
A recurring `RefreshDueFeedsJob` enqueues a `FeedRefreshJob` for each feed
that hasn't been fetched in the last 30 minutes (see `config/recurring.yml`).

To refresh a single feed manually:

```ruby
FeedRefreshJob.perform_now(Feed.first.id)
```

## Bilibili feeds

Pasting a `space.bilibili.com/<uid>` address subscribes to that user's video
uploads. Intended for personal use and **off by default in production** — see
[docs/bilibili-feeds.md](docs/bilibili-feeds.md).

## Search

Full-text search uses Postgres `tsvector` with `websearch_to_tsquery`,
ranking title (A) > summary (B) > content (C) > author (D). The vector is
maintained in the `Entry` model's `before_save`.

## Tests

```bash
bin/rails test
```

## Backups

Production `drift_production` is dumped every few hours and pushed off-server to
S3-compatible object storage (R2 / B2) by a Kamal **backup accessory** — a
sidecar built from official `postgres:16` + AWS CLI. Tooling lives in
[`backup/`](backup); setup, retention, and restore drills are in
[docs/backups.md](docs/backups.md).

## License

Drift is free software, licensed under the **GNU Affero General Public License
v3.0** (AGPL-3.0). See [LICENSE](LICENSE). In short: you may use, modify, and
self-host it, but if you run a modified version as a network service, you must
make your source available to its users under the same license.
