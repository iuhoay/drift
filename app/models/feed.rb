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

  has_many :entries, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions

  normalizes :feed_url, with: ->(url) { url.strip }

  # `kind` selects the refresh strategy and is derived from the URL: a Bilibili
  # space serves no RSS, so we synthesize one via Feed::Bilibili instead of
  # GETting the page. Deriving it here means the subscribe flow needs no change.
  before_validation :assign_kind

  validates :feed_url, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: %r{\Ahttps?://\S+\z}i }
  validates :kind, inclusion: { in: %w[rss bilibili] }

  scope :due_for_refresh, ->(interval: 30.minutes) {
    where("last_fetched_at IS NULL OR last_fetched_at < ?", interval.ago)
  }

  def bilibili?
    kind == "bilibili"
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
end
