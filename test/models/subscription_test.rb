require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "is unique per user and feed" do
    duplicate = users(:one).subscriptions.build(feed: feeds(:example))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "different users may subscribe to the same feed" do
    new_user = User.create!(email_address: "new@example.com", password: "password1")
    subscription = new_user.subscriptions.build(feed: feeds(:example))
    assert subscription.valid?
  end

  test "display_title prefers custom_title, then feed title" do
    custom = subscriptions(:one_stale)
    assert_equal "My Stale Feed", custom.display_title

    plain = subscriptions(:one_example)
    assert_equal feeds(:example).title, plain.display_title
  end
end
