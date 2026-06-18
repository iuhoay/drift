require "nokogiri"
require "readability"
require "sanitize"
require "uri"

# Enriches a freshly saved page with server-side metadata and a readable copy of
# the article. Fetches through Feed.http_connection so it inherits the SSRF
# guard, User-Agent, redirect limit, and timeouts already used for feeds. Only
# blank fields are filled, so a title the extension captured from the tab is
# never clobbered.
#
# `content` is a Readability-extracted, sanitized, URL-absolutized copy of the
# article body, rendered as the in-app reader view. Extraction failures (or
# pages that aren't really articles) leave it blank and the show page falls back
# to the excerpt card.
#
# Mirrors Feed::Refresher: this PORO holds the fetch + parse logic and `http` is
# injectable for tests, while SavedItemFetchJob is just the queue adapter.
class SavedItem::Fetcher
  EXCERPT_LIMIT = 280

  # Below this much plain text, a page isn't a real article (landing pages, error
  # pages, link shorteners) — skip the reader view rather than store a stub.
  MIN_CONTENT_LENGTH = 200

  # Tags/attributes Readability keeps in its output. Its default whitelist is
  # just div/p, which strips images and links; a reader view wants both.
  READABILITY_TAGS = %w[
    div p span br a img figure figcaption blockquote pre code
    h1 h2 h3 h4 h5 h6 ul ol li table thead tbody tr td th strong em b i
  ].freeze
  READABILITY_ATTRS = %w[href src alt title].freeze

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
    @item.title     = extract_title(doc)                        if @item.title.blank?
    @item.excerpt   = extract_excerpt(doc)                      if @item.excerpt.blank?
    @item.site_name = extract_site_name(doc)                    if @item.site_name.blank?
    @item.image_url = extract_image(doc)                        if @item.image_url.blank?
    @item.content   = extract_content(response.body, @item.url) if @item.content.blank?
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

  # Pulls the main article body, sanitizes it, and rewrites relative links/images
  # to absolute URLs so the reader view renders correctly off-site. Returns nil
  # for non-articles (too little text) or on any extraction error.
  def extract_content(html, base_url)
    article = Readability::Document.new(
      html, tags: READABILITY_TAGS, attributes: READABILITY_ATTRS, remove_empty_nodes: true
    ).content

    cleaned = Sanitize.fragment(article.to_s, Sanitize::Config::RELAXED)
    return nil if plain_length(cleaned) < MIN_CONTENT_LENGTH

    absolutize(cleaned, base_url).presence
  rescue StandardError
    nil
  end

  def absolutize(html, base_url)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("a[href]").each { |a| a["href"] = absolute(a["href"], base_url) }
    fragment.css("img[src]").each { |img| img["src"] = absolute(img["src"], base_url) }
    fragment.to_html
  end

  def absolute(url, base_url)
    URI.join(base_url, url).to_s
  rescue URI::Error
    url
  end

  def plain_length(html)
    ActionController::Base.helpers.strip_tags(html).gsub(/\s+/, " ").strip.length
  end

  def meta(doc, property: nil, name: nil)
    selector = property ? "meta[property='#{property}']" : "meta[name='#{name}']"
    doc.at_css(selector)&.[]("content")&.strip
  end
end
