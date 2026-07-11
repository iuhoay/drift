require "uri"

# A page the user saved to read later, captured from any tab via the browser
# extension (or pasted into the web UI). Unlike Entry — shared content polled
# from a Feed — a SavedItem is personal, so it belongs straight to the user and
# carries its own read/starred state through Readable rather than UserEntry.
#
# Capture is metadata-only: the extension posts the URL (and the tab title), and
# SavedItemFetchJob fills in title/excerpt/site_name/image_url server-side via
# Feed.http_connection (reusing the SSRF guard). Reading opens the original site.
# == Schema Information
#
# Table name: saved_items
#
#  id            :bigint           not null, primary key
#  content       :text
#  excerpt       :text
#  image_url     :string
#  read_at       :datetime
#  saved_at      :datetime         not null
#  search_vector :tsvector
#  site_name     :string
#  starred_at    :datetime
#  title         :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_saved_items_on_search_vector           (search_vector) USING gin
#  index_saved_items_on_user_id                 (user_id)
#  index_saved_items_on_user_id_and_read_at     (user_id,read_at)
#  index_saved_items_on_user_id_and_saved_at    (user_id,saved_at)
#  index_saved_items_on_user_id_and_starred_at  (user_id,starred_at)
#  index_saved_items_on_user_id_and_url         (user_id,url) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class SavedItem < ApplicationRecord
  include Readable
  include Searchable

  belongs_to :user

  normalizes :url, with: ->(url) { url.strip }

  validates :url, presence: true,
                  format: { with: %r{\Ahttps?://\S+\z}i },
                  uniqueness: { scope: :user_id, case_sensitive: false }

  before_validation :assign_saved_at, on: :create

  search_columns title: "A", excerpt: "B", content: "C"

  scope :recent, -> { order(saved_at: :desc) }

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
end
