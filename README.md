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

## Background jobs

Solid Queue runs in-process via `bin/jobs` (started by `bin/dev`).
A recurring `RefreshDueFeedsJob` enqueues a `FeedRefreshJob` for each feed
that hasn't been fetched in the last 30 minutes (see `config/recurring.yml`).

To refresh a single feed manually:

```ruby
FeedRefreshJob.perform_now(Feed.first.id)
```

## Search

Full-text search uses Postgres `tsvector` with `websearch_to_tsquery`,
ranking title (A) > summary (B) > content (C) > author (D). The vector is
maintained in the `Entry` model's `before_save`.

## Tests

```bash
bin/rails test
```
