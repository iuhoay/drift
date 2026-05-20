require "feedjira"
require "faraday"
require "faraday/follow_redirects"
require "sanitize"

class Feed::Refresher
  USER_AGENT = "Drift RSS Reader/0.1 (+https://drift.local)"
  TIMEOUT = 15

  def self.call(feed)
    new(feed).call
  end

  def initialize(feed)
    @feed = feed
  end

  def call
    response = http.get(@feed.feed_url) do |req|
      req.headers["User-Agent"] = USER_AGENT
      req.headers["If-None-Match"] = @feed.etag if @feed.etag.present?
      req.headers["If-Modified-Since"] = @feed.last_modified if @feed.last_modified.present?
    end

    case response.status
    when 304
      record_success(response)
    when 200..299
      parsed = Feedjira.parse(response.body)
      apply!(parsed, response)
      record_success(response)
    else
      record_failure("HTTP #{response.status}")
    end
    @feed
  rescue Faraday::Error => e
    record_failure("HTTP error: #{e.message}")
    @feed
  rescue Feedjira::NoParserAvailable => e
    record_failure("Parse error: #{e.message}")
    @feed
  end

  private

  def http
    @http ||= Faraday.new do |f|
      f.response :follow_redirects, limit: 5
      f.options.timeout = TIMEOUT
      f.options.open_timeout = TIMEOUT
    end
  end

  def apply!(parsed, response)
    @feed.title = parsed.title.presence || @feed.title
    @feed.site_url = parsed.url.presence || @feed.site_url
    @feed.description = parsed.description.presence || @feed.description if parsed.respond_to?(:description)
    @feed.etag = response.headers["etag"].presence
    @feed.last_modified = response.headers["last-modified"].presence

    parsed.entries.each { |raw| upsert_entry(raw) }
  end

  def upsert_entry(raw)
    guid = (raw.entry_id.presence || raw.url.presence || raw.title.to_s).to_s.first(1024)
    return if guid.blank?

    entry = @feed.entries.find_or_initialize_by(guid: guid)
    entry.url = raw.url.presence || entry.url
    entry.title = raw.title.presence || entry.title || "(untitled)"
    entry.author = raw.respond_to?(:author) ? raw.author.to_s.presence : nil
    entry.summary = sanitize(raw.summary.presence)
    entry.content = sanitize(raw.content.presence || raw.summary.presence)
    entry.published_at = raw.published || raw.updated || entry.published_at || Time.current
    entry.save!
  end

  def sanitize(html)
    return nil if html.blank?

    Sanitize.fragment(html, Sanitize::Config::RELAXED)
  end

  def record_success(response)
    @feed.update!(
      last_fetched_at: Time.current,
      last_success_at: Time.current,
      last_error: nil,
      fetch_failure_count: 0,
      etag: response.headers["etag"].presence || @feed.etag,
      last_modified: response.headers["last-modified"].presence || @feed.last_modified
    )
  end

  def record_failure(message)
    @feed.update!(
      last_fetched_at: Time.current,
      last_error: message,
      fetch_failure_count: @feed.fetch_failure_count + 1
    )
  end
end
