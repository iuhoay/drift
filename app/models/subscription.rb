# == Schema Information
#
# Table name: subscriptions
#
#  id           :bigint           not null, primary key
#  custom_title :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  feed_id      :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_feed_id              (feed_id)
#  index_subscriptions_on_user_id              (user_id)
#  index_subscriptions_on_user_id_and_feed_id  (user_id,feed_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (feed_id => feeds.id)
#  fk_rails_...  (user_id => users.id)
#
class Subscription < ApplicationRecord
  include Subscribing

  belongs_to :user
  belongs_to :feed

  validates :user_id, uniqueness: { scope: :feed_id }

  def display_title
    custom_title.presence || feed.display_title
  end
end
