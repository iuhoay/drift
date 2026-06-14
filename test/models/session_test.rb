require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "touch_last_active records activity when never seen" do
    session = users(:one).sessions.create!

    assert_nil session.last_active_at
    session.touch_last_active
    assert_not_nil session.reload.last_active_at
  end

  test "touch_last_active is throttled within the active window" do
    now = Time.current
    session = users(:one).sessions.create!(last_active_at: now)

    session.touch_last_active(now + 1.minute)
    assert_equal now.to_i, session.reload.last_active_at.to_i
  end

  test "touch_last_active refreshes once the window has passed" do
    now = Time.current
    session = users(:one).sessions.create!(last_active_at: now - 1.hour)

    session.touch_last_active(now)
    assert_equal now.to_i, session.reload.last_active_at.to_i
  end
end
