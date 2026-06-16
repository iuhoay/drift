class User < ApplicationRecord
  # Reading preferences applied to the article body (`.entry-content`). The
  # values double as the `data-reading-*` attribute on <html> and the CSS hook
  # that swaps the font/size — keep them in sync with app/assets/tailwind.
  READING_FONTS = %w[mono sans serif].freeze
  READING_FONT_SIZES = %w[small medium large xlarge].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :identities, dependent: :destroy

  has_many :subscriptions, dependent: :destroy
  has_many :feeds, through: :subscriptions
  has_many :user_entries, dependent: :destroy
  has_many :entries, through: :user_entries

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :reading_font, inclusion: { in: READING_FONTS }
  validates :reading_font_size, inclusion: { in: READING_FONT_SIZES }

  # Email-verification link token. Tied to the current email address, so it
  # stops working the moment the address changes (re-verification on change).
  generates_token_for :email_verification, expires_in: 1.day do
    email_address
  end

  def verified?
    verified_at.present?
  end

  def verify!
    update_column(:verified_at, Time.current) unless verified?
  end

  def subscribed_entries
    Entry.joins(feed: :subscriptions).where(subscriptions: { user_id: id })
  end

  # Activity events per calendar day on/after `date`, as { Date => count }.
  # Counts entries read, entries starred, and feeds added.
  def activity_by_day_since(date)
    since = date.beginning_of_day
    sources = [
      user_entries.where("read_at >= ?", since).group(Arel.sql("read_at::date")).count,
      user_entries.where("starred_at >= ?", since).group(Arel.sql("starred_at::date")).count,
      subscriptions.where("subscriptions.created_at >= ?", since).group(Arel.sql("subscriptions.created_at::date")).count
    ]

    sources.each_with_object(Hash.new(0)) do |counts, totals|
      counts.each do |day, n|
        totals[day.is_a?(Date) ? day : Date.parse(day.to_s)] += n
      end
    end
  end
end
