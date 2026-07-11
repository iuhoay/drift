# A long-lived bearer token the browser extension uses to authenticate against
# the JSON API (POST /api/saved_items). Cookies are SameSite=Lax, so a cross-site
# POST from an arbitrary tab carries no session — the token fills that gap.
#
# The value is generated once and stored in plaintext (has_secure_token); the
# account UI shows it once on creation and only a masked tail afterwards. A token
# grants nothing beyond saving pages for its owner, and is revocable any time.
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
