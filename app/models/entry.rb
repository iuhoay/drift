# == Schema Information
#
# Table name: entries
#
#  id            :bigint           not null, primary key
#  author        :string
#  content       :text
#  guid          :string           not null
#  published_at  :datetime
#  search_vector :tsvector
#  summary       :text
#  title         :string
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  feed_id       :bigint           not null
#
# Indexes
#
#  index_entries_on_feed_id           (feed_id)
#  index_entries_on_feed_id_and_guid  (feed_id,guid) UNIQUE
#  index_entries_on_published_at      (published_at)
#  index_entries_on_search_vector     (search_vector) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (feed_id => feeds.id)
#
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
