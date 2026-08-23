# == Schema Information
#
# Table name: subscriptions
#
#  id           :bigint           not null, primary key
#  category     :string
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
  validates :category, length: { maximum: 40 }, allow_nil: true

  normalizes :category, with: ->(value) { value.to_s.strip.gsub(/[[:space:]]+/, " ").presence }

  def display_title
    custom_title.presence || feed.display_title
  end

  # Case-insensitive match on the user-typed label. Qualify the column so
  # this can be merged into Entry queries that already join subscriptions.
  def self.with_category(name)
    where("LOWER(#{table_name}.category) = ?", name.to_s.strip.downcase)
  end
end
