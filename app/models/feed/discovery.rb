require "feedjira"
require "faraday"
require "faraday/follow_redirects"
require "nokogiri"

# Resolves a human-pasted address (e.g. "https://www.ruanyifeng.com/blog/")
# into the actual RSS/Atom feed URL(s) behind it, so users don't have to hunt
# for the feed link themselves.
#
# Resolution order:
#   1. If the address already returns a parseable feed, use it as-is.
#   2. Otherwise look for <link rel="alternate"> feed tags in the page's HTML.
#   3. As a last resort, probe a handful of conventional feed paths.
#
# Returns an array of absolute feed URLs (most likely first), or [] when
# nothing parses as a feed.
class Feed::Discovery
  TIMEOUT = 15

  # <link type="..."> values that advertise a feed in an HTML <head>.
  FEED_LINK_TYPES = [
    "application/rss+xml",
    "application/atom+xml",
    "application/feed+json"
  ].freeze

  # Conventional locations to probe when a page advertises no feed, resolved
  # relative to the fetched page.
  COMMON_PATHS = %w[
    feed feed.xml atom.xml rss rss.xml index.xml
  ].freeze

  def self.call(url)
    new(url).call
  end

  def initialize(url, http: nil)
    @url = url.to_s.strip
    @http = http
  end

  def call
    return [] if @url.blank?

    response = get(@url)
    return [] unless response&.success?

    base_uri = response.env.url

    return [ base_uri.to_s ] if feed?(response.body)

    links = links_from_html(response.body, base_uri)
    return links if links.any?

    probe_common_paths(base_uri)
  end

  private

  def http
    @http ||= Faraday.new do |f|
      f.response :follow_redirects, limit: 5
      f.options.timeout = TIMEOUT
      f.options.open_timeout = TIMEOUT
    end
  end

  def get(url)
    http.get(url) { |req| req.headers["User-Agent"] = Feed::USER_AGENT }
  rescue StandardError
    nil
  end

  def feed?(body)
    return false if body.blank?

    Feedjira.parse(body)
    true
  rescue StandardError
    false
  end

  def links_from_html(body, base_uri)
    return [] if body.blank?

    Nokogiri::HTML(body).css("link[type]").filter_map { |link|
      type = link["type"].to_s.strip.downcase
      next unless FEED_LINK_TYPES.include?(type)

      rel = link["rel"].to_s.downcase
      next unless rel.include?("alternate") || rel.include?("feed")

      href = link["href"].to_s.strip
      next if href.blank?

      absolutize(href, base_uri)
    }.uniq
  rescue StandardError
    []
  end

  def probe_common_paths(base_uri)
    COMMON_PATHS.each do |path|
      candidate = absolutize(path, base_uri)
      next if candidate.blank?

      response = get(candidate)
      return [ candidate ] if response&.success? && feed?(response.body)
    end
    []
  end

  def absolutize(href, base_uri)
    base_uri.merge(href).to_s
  rescue StandardError
    nil
  end
end
