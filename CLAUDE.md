# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Stack

- Ruby 4.0.2, Rails 8.2.0.alpha (tracking the `main` branch on GitHub)
- PostgreSQL — production uses separate `primary`, `cache`, `queue`, `cable` databases (see `config/database.yml`); development uses one DB with all Solid schemas loaded into it
- Solid Queue / Solid Cache / Solid Cable (no Redis)
- Importmap (no JS bundler), Tailwind CSS v4, Hotwire (Turbo + Stimulus)
- Minitest (parallelized), `rubocop-rails-omakase` for style
- Feedjira (RSS), Faraday (HTTP with ETag / If-Modified-Since), Sanitize (HTML), ruby-readability (`require: "readability"` — SavedItem full-article extraction)

## Commands

- `bin/dev` — Foreman: web, Tailwind watcher, Solid Queue worker
- `bin/jobs` — Solid Queue CLI standalone
- `bin/setup` — bootstrap dev (idempotent); requires Postgres reachable and `.env` configured
- `bin/rails test` — Minitest. Rails 8.2's `creds` only merges `.env` in dev, so test sees nil from `creds.option(...)`; `config/database.yml` carries `root` / `password` defaults on each call as the local-dev fallback. Real `ENV` overrides if your Postgres differs. See atom `invariant_dotenv_test_env`.
- `bin/rubocop` — omakase style (Ruby files only)
- `bin/ci` — full local gate before a PR (config in `config/ci.rb`): setup + RuboCop + bundler-audit + importmap audit + Brakeman + tests. GitHub Actions runs the same plus Capybara system tests.
- `bin/rails search:reindex` — rebuild every `Entry` and `SavedItem` search vector after a tokenization change; in production run it through the `bin/kamal reindex` alias after deploying the new tokenizer.
- Recurring (`config/recurring.yml`): `RefreshDueFeedsJob` every 10 min (all envs); production also renews WebSub leases (6 h), clears finished Solid Queue jobs (hourly), and runs Rails Pulse summarize/cleanup.
- Config is read via `Rails.app.creds.option(...)` (merges `.env` in dev, encrypted credentials in prod) — not stock `Rails.application.credentials` or bare `ENV`.
- Deploy: Kamal (`config/deploy.yml`, host `rdrift.app`, `bin/kamal`).

## Domain

RSS reader: `Feed` → `Subscription` (user↔feed) → `Entry` → `UserEntry` (per-user `read_at`/`starred_at`, created lazily). Auth is the Rails 8 generator (DB-backed `Session`) plus a hand-written `RegistrationsController`, OAuth via OmniAuth (`Identity` — GitHub/Google), and long-lived `ApiToken`s for the browser extension's JSON API. Full-text search lives in the `Searchable` concern (shared by `Entry` and `SavedItem`), not on `Entry` directly — weighted `tsvector` (title A > summary B > content C > author D) rebuilt before_save. CJK indexing stores both unigrams and overlapping 2-grams, while queries use 2-grams except for a lone CJK character; this preserves precise sub-word matching and lets single-character searches match without a server-side parser.

Feeds aren't all polled RSS: `Feed::Discovery` resolves a pasted site URL to its feed, `Feed::Bilibili` is an in-house adapter (`Feed#kind`) for sites with no native RSS, and YouTube uses WebSub push (`WebSubSubscription`) instead of polling. `Feed::PublicAddressGuard` is an SSRF guard on all outbound feed fetches.

`SavedItem` is a separate read-later library (browser-extension / pasted URLs) that fetches the **full** article via `SavedItem::Fetcher` and carries its own `read_at`/`starred_at` through `Readable`.

**Star vs. save — intentionally NOT bridged.** Do not add a "save feed entry to read later" action. It overlaps with entry **star** (`UserEntry.starred_at`), which is the single "come back to this feed entry" affordance. Star is a lightweight flag on a feed-owned `Entry`; `SavedItem` is a personal, durable, full-text copy. They were deliberately kept separate (decision 2026-06-20). Only revisit if a concrete need appears for permanently archiving the *full text* of a feed entry whose feed truncates content — and if so, add it as a deliberate "Save full copy" action on the entry **show** page only, never as a second list-row toggle next to star.

Vanilla Rails philosophy — rich models, thin controllers, no service-object layer. The deliberate exceptions are the POROs under `app/models/**` that do HTTP fetch / parse / orchestration — `Feed::Refresher`, `Feed::Discovery`, `Feed::Bilibili`, `Feed::PublicAddressGuard` (a Faraday middleware), `Subscription::Subscribing`, and `SavedItem::Fetcher` — each typically paired with an Active Job in `app/jobs`.

An admin-gated area (`namespace :admin`, `Admin::BaseController`) fronts operational dashboards: Rails Pulse at `/rails_pulse` and Mission Control Jobs at `/jobs`; errors report to Honeybadger. In development, Mailbin previews mail at `/mailbin`.

## Conventions

- Tests: prefer fixtures over factories; use `dom_id(record)` + `assert_select` for view assertions
- Frozen string literals are enforced (`.rubocop.yml` `StringLiteralsFrozenByDefault: true`, kept in sync with `config/bootsnap.rb`) — write code assuming string literals are frozen.
- Test helpers (`test/test_helpers/`, auto-included): `stub_discovery` swaps `Feed::Discovery.call` so subscribe tests don't hit the network; `SessionTestHelper` provides sign-in helpers; `include ActiveJob::TestHelper` for `assert_enqueued_with`.
