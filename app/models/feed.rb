class Feed < ApplicationRecord
  # Sent on every outbound HTTP request we make on a feed's behalf
  # (discovery and refresh). Defined here so the two share one source of truth.
  USER_AGENT = "Drift RSS Reader/0.1 (+https://rdrift.app)"

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

  validates :feed_url, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: %r{\Ahttps?://\S+\z}i }

  scope :due_for_refresh, ->(interval: 30.minutes) {
    where("last_fetched_at IS NULL OR last_fetched_at < ?", interval.ago)
  }

  def display_title
    title.presence || feed_url
  end

  def healthy?
    fetch_failure_count.zero?
  end
end
