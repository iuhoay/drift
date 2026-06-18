class Subscription < ApplicationRecord
  include Subscribing

  belongs_to :user
  belongs_to :feed

  validates :user_id, uniqueness: { scope: :feed_id }

  def display_title
    custom_title.presence || feed.display_title
  end
end
