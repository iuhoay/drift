require "nokogiri"
require "readability"
require "sanitize"
require "uri"

# Pulls the readable article body out of a fetched HTML page: Readability
# extraction, sanitization, and rewriting relative links/images to absolute
# URLs so the result renders correctly off-site. Returns nil for pages that
# aren't really articles (too little text) or on any extraction error.
#
# Shared by SavedItem::Fetcher (read-it-later captures) and Entry::Scraper
# (full text for entries whose feed truncates or omits the body).
class ArticleExtractor
  # Below this much plain text, a page isn't a real article (landing pages,
  # error pages, link shorteners) — skip it rather than store a stub.
  MIN_CONTENT_LENGTH = 200

  # Tags/attributes Readability keeps in its output. Its default whitelist is
  # just div/p, which strips images and links; a reader view wants both.
  READABILITY_TAGS = %w[
    div p span br a img figure figcaption blockquote pre code
    h1 h2 h3 h4 h5 h6 ul ol li table thead tbody tr td th strong em b i
  ].freeze
  READABILITY_ATTRS = %w[href src alt title].freeze

  def self.extract(html, base_url)
    new(html, base_url).extract
  end

  def initialize(html, base_url)
    @html = html
    @base_url = base_url
  end

  def extract
    article = Readability::Document.new(
      @html, tags: READABILITY_TAGS, attributes: READABILITY_ATTRS, remove_empty_nodes: true
    ).content

    cleaned = Sanitize.fragment(article.to_s, Sanitize::Config::RELAXED)
    return nil if plain_length(cleaned) < MIN_CONTENT_LENGTH

    absolutize(cleaned).presence
  rescue StandardError
    nil
  end

  private

  def absolutize(html)
    fragment = Nokogiri::HTML.fragment(html)
    fragment.css("a[href]").each { |a| a["href"] = absolute(a["href"]) }
    fragment.css("img[src]").each { |img| img["src"] = absolute(img["src"]) }
    fragment.to_html
  end

  def absolute(url)
    URI.join(@base_url, url).to_s
  rescue URI::Error
    url
  end

  def plain_length(html)
    ActionController::Base.helpers.strip_tags(html).gsub(/\s+/, " ").strip.length
  end
end
