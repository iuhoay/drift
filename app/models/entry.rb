class Entry < ApplicationRecord
  include Searchable

  belongs_to :feed
  has_many :user_entries, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  search_columns title: "A", summary: "B", content: "C", author: "D"

  scope :recent, -> { order(Arel.sql("COALESCE(entries.published_at, entries.created_at) DESC")) }

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
end
