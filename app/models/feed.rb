class Feed < ApplicationRecord
  has_many :entries, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions

  normalizes :feed_url, with: ->(url) { url.strip }

  validates :feed_url, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: %r{\Ahttps?://\S+\z}i }

  scope :due_for_refresh, ->(interval: 30.minutes) {
    where("last_fetched_at IS NULL OR last_fetched_at < ?", interval.ago)
  }

  def display_title
    title.presence || feed_url
  end

  def healthy?
    fetch_failure_count.zero?
  end
end
