require "nokogiri"
require "uri"

# Enriches a freshly saved page with server-side metadata: a clean title, a
# short excerpt, the site name, and a lead image. Fetches through
# Feed.http_connection so it inherits the SSRF guard, User-Agent, redirect
# limit, and timeouts already used for feeds. Only blank fields are filled, so a
# title the extension captured from the tab is never clobbered.
#
# `http` is injectable for tests (call SavedItemFetchJob.new.perform(id, http:)
# directly); perform_later enqueues only the id and defaults to the real one.
class SavedItemFetchJob < ApplicationJob
  queue_as :default

  EXCERPT_LIMIT = 280

  def perform(saved_item_id, http: nil)
    item = SavedItem.find_by(id: saved_item_id)
    return unless item

    response = (http || Feed.http_connection).get(item.url)
    return unless response.status.in?(200..299)

    doc = Nokogiri::HTML(response.body)
    item.title     = extract_title(doc)            if item.title.blank?
    item.excerpt   = extract_excerpt(doc)          if item.excerpt.blank?
    item.site_name = extract_site_name(doc, item)  if item.site_name.blank?
    item.image_url = extract_image(doc, item)      if item.image_url.blank?
    item.save!
  rescue Faraday::Error
    # Leave the item with whatever the extension provided; a transient fetch
    # failure shouldn't drop the save.
  end

  private

  def extract_title(doc)
    meta(doc, property: "og:title").presence ||
      doc.at_css("title")&.text&.strip.presence
  end

  def extract_excerpt(doc)
    text = meta(doc, property: "og:description").presence ||
           meta(doc, name: "description").presence
    text&.gsub(/\s+/, " ")&.strip&.truncate(EXCERPT_LIMIT)
  end

  def extract_site_name(doc, item)
    meta(doc, property: "og:site_name").presence || item.host
  end

  # Resolves a possibly-relative og:image against the page URL and keeps it only
  # if it ends up an http(s) address.
  def extract_image(doc, item)
    raw = meta(doc, property: "og:image").presence
    return nil if raw.blank?

    absolute = URI.join(item.url, raw).to_s
    absolute if absolute.match?(%r{\Ahttps?://}i)
  rescue URI::Error
    nil
  end

  def meta(doc, property: nil, name: nil)
    selector = property ? "meta[property='#{property}']" : "meta[name='#{name}']"
    doc.at_css(selector)&.[]("content")&.strip
  end
end
