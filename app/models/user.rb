class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :subscriptions, dependent: :destroy
  has_many :feeds, through: :subscriptions
  has_many :user_entries, dependent: :destroy
  has_many :entries, through: :user_entries

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def subscribed_entries
    Entry.joins(feed: :subscriptions).where(subscriptions: { user_id: id })
  end
end
