# == Schema Information
#
# Table name: sessions
#
#  id             :bigint           not null, primary key
#  ip_address     :string
#  last_active_at :datetime
#  user_agent     :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_sessions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Session < ApplicationRecord
  belongs_to :user

  # How stale last_active_at may get before a request bothers to refresh it.
  # Keeps session tracking cheap (no write on every request).
  ACTIVE_TOUCH_WINDOW = 10.minutes

  # Refresh last_active_at at most once per ACTIVE_TOUCH_WINDOW so the session
  # list can show a meaningful "last seen" without a write per request.
  def touch_last_active(now = Time.current)
    return if last_active_at.present? && last_active_at > now - ACTIVE_TOUCH_WINDOW

    update_column(:last_active_at, now)
  end
end
