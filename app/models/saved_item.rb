require "uri"

# A page the user saved to read later, captured from any tab via the browser
# extension (or pasted into the web UI). Unlike Entry — shared content polled
# from a Feed — a SavedItem is personal, so it belongs straight to the user and
# carries its own read/starred state through Readable rather than UserEntry.
#
# Capture is metadata-only: the extension posts the URL (and the tab title), and
# SavedItemFetchJob fills in title/excerpt/site_name/image_url server-side via
# Feed.http_connection (reusing the SSRF guard). Reading opens the original site.
class SavedItem < ApplicationRecord
  include Readable

  belongs_to :user

  normalizes :url, with: ->(url) { url.strip }

  validates :url, presence: true,
                  format: { with: %r{\Ahttps?://\S+\z}i },
                  uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :assign_saved_at, on: :create
  before_save :assign_search_vector

  scope :recent, -> { order(saved_at: :desc) }
  scope :search, ->(query) {
    next all if query.blank?

    where("search_vector @@ websearch_to_tsquery('english', ?)", query)
      .reorder(Arel.sql("ts_rank(search_vector, websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
  }

  def display_title
    title.presence || url
  end

  def safe_url
    url if url.to_s.match?(%r{\Ahttps?://\S+\z}i)
  end

  # Falls back to the URL's host when no og:site_name was captured, so a row
  # always shows where the page came from.
  def source_label
    site_name.presence || host
  end

  def host
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end

  private

  def assign_saved_at
    self.saved_at ||= Time.current
  end

  def assign_search_vector
    return unless title_changed? || excerpt_changed?

    sql = <<~SQL.squish
      setweight(to_tsvector('english', coalesce(?, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(?, '')), 'B')
    SQL

    self.search_vector = self.class.connection.select_value(
      self.class.sanitize_sql_array([ "SELECT #{sql}", title, excerpt ])
    )
  end
end
