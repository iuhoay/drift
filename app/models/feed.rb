# == Schema Information
#
# Table name: feeds
#
#  id                  :bigint           not null, primary key
#  dead_at             :datetime
#  description         :text
#  etag                :string
#  feed_url            :string           not null
#  fetch_failure_count :integer          default(0), not null
#  kind                :string           default("rss"), not null
#  last_error          :text
#  last_fetched_at     :datetime
#  last_modified       :string
#  last_success_at     :datetime
#  next_fetch_at       :datetime
#  site_url            :string
#  title               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_feeds_on_feed_url       (feed_url) UNIQUE
#  index_feeds_on_next_fetch_at  (next_fetch_at)
#
class Feed < ApplicationRecord
  # Sent on every outbound HTTP request we make on a feed's behalf (discovery
  # and refresh). The per-environment value lives in config/feed.yml: only
  # production identifies as the bare live service, so non-production traffic is
  # distinguishable to feed operators and in our logs and never looks like real
  # production fetches.
  USER_AGENT = Rails.application.config_for(:feed).user_agent

  # Outbound HTTP timeouts (seconds). open_timeout is deliberately short so a
  # dead or hanging host fails on connect instead of pinning a request thread;
  # the read timeout is kept modest for the same reason — discovery may issue
  # several requests in series.
  HTTP_OPEN_TIMEOUT = 3
  HTTP_TIMEOUT = 10

  # Baseline poll cadence. YouTube channel feeds get a longer interval because
  # polling many channels from one IP at the default rate draws 429s, and a new
  # video can wait the interval out anyway — there's no realtime guarantee.
  REFRESH_INTERVAL = 30.minutes
  YOUTUBE_REFRESH_INTERVAL = 1.hour

  # Feeds with a live WebSub push subscription poll far less often: the hub pushes
  # new entries in near-realtime, so polling is only a safety net for missed pushes.
  # This is the scaling win — it cuts YouTube request volume ~6x per channel.
  WEBSUB_REFRESH_INTERVAL = 12.hours

  # Failure backoff: each consecutive failure doubles the wait (capped by the
  # exponent so 2** can't blow up), never exceeding MAX_BACKOFF. A server-sent
  # Retry-After overrides this — YouTube returns one with its 429s, and ignoring
  # it is exactly what keeps a rate-limited feed rate-limited.
  MAX_BACKOFF = 24.hours
  MAX_BACKOFF_EXPONENT = 6

  # Consecutive failures after which a feed is treated as dead: a deleted URL or
  # a channel whose feed has gone permanently 404/500. With the backoff above,
  # reaching this count spans several days of failed attempts, so it means
  # "we've genuinely tried for a while," not "one bad fetch." A dead feed keeps
  # polling at the backoff cap (≈daily) so it can revive on its own, but it's
  # flagged so subscribers and the dashboard see it instead of failing silently.
  DEAD_AFTER_FAILURES = 10

  # The one Faraday connection every feed fetch goes through (discovery and
  # refresh). Follows redirects, sends our User-Agent, blocks non-public
  # addresses (SSRF), and bounds how long any single request may hang.
  def self.http_connection
    Faraday.new do |f|
      f.headers["User-Agent"] = USER_AGENT
      f.response :follow_redirects, limit: 5
      f.use Feed::PublicAddressGuard
      f.options.timeout = HTTP_TIMEOUT
      f.options.open_timeout = HTTP_OPEN_TIMEOUT
    end
  end

  # Retry-After is either a number of seconds ("120") or an HTTP-date
  # ("Wed, 21 Oct 2025 07:28:00 GMT"). Returns the wait in seconds, or nil when
  # the value is blank, malformed, or already in the past.
  def self.retry_after_seconds(value)
    return nil if value.blank?
    return value.to_i if value.to_s.match?(/\A\d+\z/)

    seconds = Time.httpdate(value.to_s).to_i - Time.current.to_i
    seconds.positive? ? seconds : nil
  rescue ArgumentError
    nil
  end

  # Turns a pasted address into the feed URL behind it. A URL we already track is
  # a feed by definition, so we skip the network round-trip; anything else is run
  # through auto-detection. Returns nil when nothing there parses as a feed;
  # raises Feed::Discovery::FetchFailed when the address can't be fetched at all.
  def self.resolve_url(address)
    url = address.to_s.strip
    return url if exists?(feed_url: url)

    Feed::Discovery.call(url).first
  end

  has_many :entries, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions
  has_one :web_sub_subscription, dependent: :destroy

  normalizes :feed_url, with: ->(url) { url.strip }

  # `kind` selects the refresh strategy and is derived from the URL: a Bilibili
  # space serves no RSS, so we synthesize one via Feed::Bilibili instead of
  # GETting the page. Deriving it here means the subscribe flow needs no change.
  before_validation :assign_kind

  # YouTube polling throttles at scale, so we register a WebSub push subscription
  # for each new YouTube feed (in environments with a publicly reachable callback).
  # Covers every creation path without thickening SubscriptionsController.
  after_create_commit :subscribe_to_web_sub

  validates :feed_url, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: %r{\Ahttps?://\S+\z}i }
  validates :kind, inclusion: { in: %w[rss bilibili] }

  # next_fetch_at is the single source of truth for "may we fetch yet": the
  # refresher stamps it after every attempt (one interval out on success, a
  # backoff out on failure). NULL means never fetched, so always due.
  scope :due_for_refresh, -> {
    where("next_fetch_at IS NULL OR next_fetch_at <= ?", Time.current)
  }

  scope :dead, -> { where.not(dead_at: nil) }
  scope :alive, -> { where(dead_at: nil) }
  scope :failing, -> { where("fetch_failure_count > 0") }

  # YouTube channel feeds, identified by URL the same way #youtube? does — a
  # case-insensitive regex so the admin breakdown matches the runtime cadence.
  scope :youtube, -> { where("feed_url ~* ?", '^https?://([^/@]+\.)?youtube\.com/') }

  # Failing feeds for the admin dashboard, worst first: dead ones lead, then by
  # how hard they're failing. Carries a subscribers_count so the view can show
  # each feed's reach without an N+1.
  scope :troubled, -> {
    failing
      .left_joins(:subscriptions)
      .select("feeds.*, COUNT(subscriptions.id) AS subscribers_count")
      .group("feeds.id")
      .order(Arel.sql("feeds.dead_at IS NULL, feeds.fetch_failure_count DESC"))
  }

  def bilibili?
    kind == "bilibili"
  end

  def dead?
    dead_at.present?
  end

  def youtube?
    feed_url.match?(%r{\Ahttps?://([^/@]+\.)?youtube\.com/}i)
  end

  def refresh_interval
    return WEBSUB_REFRESH_INTERVAL if web_sub_subscription&.active?

    youtube? ? YOUTUBE_REFRESH_INTERVAL : REFRESH_INTERVAL
  end

  # Seconds to wait before the next fetch after `failures` consecutive failures.
  # Honors a server Retry-After when present; otherwise backs off exponentially
  # from refresh_interval. Always clamped to MAX_BACKOFF.
  def backoff_interval(failures, retry_after: nil)
    from_header = self.class.retry_after_seconds(retry_after)
    seconds = from_header || refresh_interval.to_i * (2**[ failures - 1, MAX_BACKOFF_EXPONENT ].min)
    [ seconds, MAX_BACKOFF.to_i ].min
  end

  # When does a feed become dead after `failures` consecutive failures? Returns
  # the existing dead_at once set (so the timestamp marks the *first* time it
  # crossed the threshold), the current time when it crosses now, or nil while
  # it's still below the threshold.
  def dead_at_after(failures, now: Time.current)
    return dead_at unless failures >= DEAD_AFTER_FAILURES

    dead_at || now
  end

  def display_title
    title.presence || feed_url
  end

  def healthy?
    fetch_failure_count.zero?
  end

  private

  def assign_kind
    self.kind = Feed::Bilibili.handles?(feed_url) ? "bilibili" : "rss"
  end

  def subscribe_to_web_sub
    return unless youtube? && WebSubSubscription.enabled?

    WebSubSubscribeJob.perform_later(id)
  end
end
