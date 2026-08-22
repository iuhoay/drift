# A long-lived bearer token for the JSON API. The browser extension uses it to
# save pages (cookies are SameSite=Lax, so a cross-site POST from an arbitrary
# tab carries no session). A CLI can use the same token to read the inbox and
# list subscriptions. There are no scopes — a token can do both.
#
# The value is generated once and stored in plaintext (has_secure_token); the
# account UI shows it once on creation and only a masked tail afterwards. A
# token is revocable any time.
# == Schema Information
#
# Table name: api_tokens
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  name         :string
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_api_tokens_on_token    (token) UNIQUE
#  index_api_tokens_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ApiToken < ApplicationRecord
  belongs_to :user

  has_secure_token

  validates :name, length: { maximum: 100 }

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # Last four characters, for display in the account UI without revealing the
  # whole secret again.
  def masked
    "••••#{token.last(4)}"
  end
end
