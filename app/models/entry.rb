class Entry < ApplicationRecord
  belongs_to :feed
  has_many :user_entries, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  before_save :assign_search_vector

  scope :recent, -> { order(Arel.sql("COALESCE(entries.published_at, entries.created_at) DESC")) }
  scope :search, ->(query) {
    next all if query.blank?

    where("search_vector @@ websearch_to_tsquery('english', ?)", query)
      .reorder(Arel.sql("ts_rank(search_vector, websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
  }

  YOUTUBE_URL = %r{\A(?:https?:)?//(?:www\.|m\.)?(?:youtube(?:-nocookie)?\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/)|youtu\.be/)([\w-]{11})}
  BILIBILI_URL = %r{\A(?:https?:)?//(?:www\.|m\.)?bilibili\.com/video/(BV[0-9A-Za-z]{10})}

  def excerpt(limit: 280)
    plain = ActionController::Base.helpers.strip_tags(summary.presence || content.to_s)
    plain.gsub(/\s+/, " ").strip.truncate(limit)
  end

  def for_user(user)
    user_entries.find_or_initialize_by(user: user)
  end

  def safe_url
    url if url.to_s.match?(%r{\Ahttps?://\S+\z}i)
  end

  def youtube_video_id
    url.to_s.match(YOUTUBE_URL)&.captures&.first
  end

  def bilibili_bvid
    url.to_s.match(BILIBILI_URL)&.captures&.first
  end

  private

  def assign_search_vector
    return unless title_changed? || summary_changed? || content_changed? || author_changed?

    sql = <<~SQL.squish
      setweight(to_tsvector('english', coalesce(?, '')), 'A') ||
      setweight(to_tsvector('english', coalesce(?, '')), 'B') ||
      setweight(to_tsvector('english', coalesce(?, '')), 'C') ||
      setweight(to_tsvector('english', coalesce(?, '')), 'D')
    SQL

    self.search_vector = self.class.connection.select_value(
      self.class.sanitize_sql_array([ "SELECT #{sql}", title, summary, content, author ])
    )
  end
end
