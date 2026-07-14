require "nokogiri"
require "uri"

# Enriches a freshly saved page with server-side metadata and a readable copy of
# the article. Fetches through Feed.http_connection so it inherits the SSRF
# guard, User-Agent, redirect limit, and timeouts already used for feeds. Only
# blank fields are filled, so a title the extension captured from the tab is
# never clobbered.
#
# `content` is a Readability-extracted, sanitized, URL-absolutized copy of the
# article body (see ArticleExtractor), rendered as the in-app reader view.
# Extraction failures (or pages that aren't really articles) leave it blank and
# the show page falls back to the excerpt card.
#
# Mirrors Feed::Refresher: this PORO holds the fetch + parse logic and `http` is
# injectable for tests, while SavedItemFetchJob is just the queue adapter.
class SavedItem::Fetcher
  EXCERPT_LIMIT = 280

  def self.call(item)
    new(item).call
  end

  # http is injectable so tests can drive the status-handling paths with a
  # Faraday test adapter; in production it defaults to Feed.http_connection.
  def initialize(item, http: nil)
    @item = item
    @http = http
  end

  def call
    response = http.get(@item.url)
    return @item unless response.status.in?(200..299)

    doc = Nokogiri::HTML(response.body)
    @item.title     = extract_title(doc)                                if @item.title.blank?
    @item.excerpt   = extract_excerpt(doc)                              if @item.excerpt.blank?
    @item.site_name = extract_site_name(doc)                            if @item.site_name.blank?
    @item.image_url = extract_image(doc)                                if @item.image_url.blank?
    @item.content   = ArticleExtractor.extract(response.body, @item.url) if @item.content.blank?
    @item.save!
    @item
  rescue Faraday::Error
    # Leave the item with whatever the extension provided; a transient fetch
    # failure shouldn't drop the save.
    @item
  end

  private

  def http
    @http ||= Feed.http_connection
  end

  def extract_title(doc)
    meta(doc, property: "og:title").presence ||
      doc.at_css("title")&.text&.strip.presence
  end

  def extract_excerpt(doc)
    text = meta(doc, property: "og:description").presence ||
           meta(doc, name: "description").presence
    text&.gsub(/\s+/, " ")&.strip&.truncate(EXCERPT_LIMIT)
  end

  def extract_site_name(doc)
    meta(doc, property: "og:site_name").presence || @item.host
  end

  # Resolves a possibly-relative og:image against the page URL and keeps it only
  # if it ends up an http(s) address.
  def extract_image(doc)
    raw = meta(doc, property: "og:image").presence
    return nil if raw.blank?

    absolute = URI.join(@item.url, raw).to_s
    absolute if absolute.match?(%r{\Ahttps?://}i)
  rescue URI::Error
    nil
  end

  def meta(doc, property: nil, name: nil)
    selector = property ? "meta[property='#{property}']" : "meta[name='#{name}']"
    doc.at_css(selector)&.[]("content")&.strip
  end
end
