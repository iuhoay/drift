require "feedjira"
require "faraday"
require "sanitize"

class Feed::Refresher
  def self.call(feed)
    new(feed).call
  end

  # Ingests an Atom payload pushed to us by a WebSub hub (see WebSubSubscription),
  # reusing the same parse + upsert path as a polled fetch. A push body is just a
  # feed containing the changed entries, so it flows through apply!/upsert_entry
  # unchanged. There's no HTTP response, so success is recorded with a nil response.
  def self.ingest(feed, body)
    new(feed).ingest(body)
  end

  # http is injectable so tests can drive the status-handling paths with a
  # Faraday test adapter; in production it defaults to Feed.http_connection.
  def initialize(feed, http: nil)
    @feed = feed
    @http = http
  end

  def call
    @feed.bilibili? ? refresh_from_source : refresh_over_http
    @feed
  rescue Faraday::Error => e
    record_failure("HTTP error: #{e.message}")
    @feed
  rescue Feedjira::NoParserAvailable => e
    record_failure("Parse error: #{e.message}")
    @feed
  end

  def ingest(body)
    apply!(Feedjira.parse(body), nil)
    record_success(nil)
    @feed
  rescue Feedjira::NoParserAvailable => e
    record_failure("Push parse error: #{e.message}")
    @feed
  end

  private

  def refresh_over_http
    response = http.get(@feed.feed_url) do |req|
      req.headers["If-None-Match"] = @feed.etag if @feed.etag.present?
      req.headers["If-Modified-Since"] = @feed.last_modified if @feed.last_modified.present?
    end

    case response.status
    when 304
      record_success(response)
    when 200..299
      apply!(Feedjira.parse(response.body), response)
      record_success(response)
    else
      record_failure("HTTP #{response.status}", response: response)
    end
  end

  # Feeds with no RSS of their own (e.g. Bilibili) are built from a source that
  # returns a parsed-feed-shaped object. There's no HTTP response to carry an
  # ETag, so apply!/record_success run with a nil response.
  def refresh_from_source
    apply!(Feed::Bilibili.fetch(@feed, http), nil)
    record_success(nil)
  rescue Feed::Bilibili::Error => e
    record_failure(e.message)
  end

  def http
    @http ||= Feed.http_connection
  end

  def apply!(parsed, response)
    @feed.title = parsed.title.presence || @feed.title
    @feed.site_url = parsed.url.presence || @feed.site_url
    @feed.description = parsed.description.presence || @feed.description if parsed.respond_to?(:description)
    if response
      @feed.etag = response.headers["etag"].presence
      @feed.last_modified = response.headers["last-modified"].presence
    end

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
      next_fetch_at: Time.current + @feed.refresh_interval,
      dead_at: nil,
      etag: response&.headers&.[]("etag").presence || @feed.etag,
      last_modified: response&.headers&.[]("last-modified").presence || @feed.last_modified
    )
  end

  def record_failure(message, response: nil)
    failures = @feed.fetch_failure_count + 1
    retry_after = response&.headers&.[]("retry-after")
    @feed.update!(
      last_fetched_at: Time.current,
      last_error: message,
      fetch_failure_count: failures,
      next_fetch_at: Time.current + @feed.backoff_interval(failures, retry_after: retry_after),
      dead_at: @feed.dead_at_after(failures)
    )
  end
end
