# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Stack

- Ruby 4.0.2, Rails 8.2.0.alpha (tracking the `main` branch on GitHub)
- PostgreSQL — production uses separate `primary`, `cache`, `queue`, `cable` databases (see `config/database.yml`); development uses one DB with all Solid schemas loaded into it
- Solid Queue / Solid Cache / Solid Cable (no Redis)
- Importmap (no JS bundler), Tailwind CSS v4, Hotwire (Turbo + Stimulus)
- Minitest (parallelized), `rubocop-rails-omakase` for style
- Feedjira (RSS), Faraday (HTTP with ETag / If-Modified-Since), Sanitize (HTML)

## Commands

- `bin/dev` — Foreman: web, Tailwind watcher, Solid Queue worker
- `bin/jobs` — Solid Queue CLI standalone
- `bin/setup` — bootstrap dev (idempotent); requires Postgres reachable and `.env` configured
- `bin/rails test` — Minitest. Rails 8.2's `creds` only merges `.env` in dev, so test sees nil from `creds.option(...)`; `config/database.yml` carries `root` / `password` defaults on each call as the local-dev fallback. Real `ENV` overrides if your Postgres differs. See atom `invariant_dotenv_test_env`.
- `bin/rubocop` — omakase style; CI also runs Brakeman, bundler-audit, importmap audit
- Recurring: `RefreshDueFeedsJob` every 10 min (dev) via `config/recurring.yml`

## Domain

RSS reader: `Feed` → `Subscription` (user↔feed) → `Entry` → `UserEntry` (per-user `read_at`/`starred_at`, created lazily). Auth is the Rails 8 generator (DB-backed `Session`) plus a hand-written `RegistrationsController`. Full-text search via Postgres `tsvector` (title A > summary B > content C > author D), maintained in `Entry` before_save.

Vanilla Rails philosophy — rich models, thin controllers, no service-object layer. The one exception is `Feed::Refresher` (HTTP fetch + parse).

## Conventions

- Unix line endings (LF)
- Run Rubocop only on Ruby files
- Tests: prefer fixtures over factories; use `dom_id(record)` + `assert_select` for view assertions
