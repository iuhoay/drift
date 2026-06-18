require "test_helper"

class Admin::WebSubSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out users are sent to sign in" do
    get admin_web_sub_subscriptions_path
    assert_redirected_to new_session_path
  end

  test "non-admin users are denied" do
    sign_in_as users(:one)
    get admin_web_sub_subscriptions_path
    assert_redirected_to root_path
    assert_equal "Access denied", flash[:alert]
  end

  test "admin sees the dashboard with the active subscription's feed" do
    sign_in_as users(:admin)
    get admin_web_sub_subscriptions_path

    assert_response :success
    assert_select "header", text: /websub/i
    assert_includes @response.body, "// at a glance"
    assert_includes @response.body, "// subscriptions"
    assert_includes @response.body, feeds(:youtube).display_title
  end

  test "denied and expired subscriptions surface under needs attention" do
    denied  = feeds(:example).create_web_sub_subscription!(state: "denied")
    expired = feeds(:stale).create_web_sub_subscription!(state: "expired", lease_expires_at: 1.day.ago)

    sign_in_as users(:admin)
    get admin_web_sub_subscriptions_path

    assert_response :success
    assert_includes @response.body, "// needs attention"
    assert_includes @response.body, denied.feed.display_title
    assert_includes @response.body, expired.feed.display_title
  end

  test "a confirmed subscription whose lease has lapsed is flagged as lapsed" do
    feeds(:example).create_web_sub_subscription!(state: "active", lease_expires_at: 1.hour.ago)

    sign_in_as users(:admin)
    get admin_web_sub_subscriptions_path

    assert_response :success
    assert_includes @response.body, "// needs attention"
    assert_select "span", text: /lapsed/i
  end

  test "the empty state shows when there are no subscriptions" do
    WebSubSubscription.delete_all

    sign_in_as users(:admin)
    get admin_web_sub_subscriptions_path

    assert_response :success
    assert_includes @response.body, "No push subscriptions yet."
  end
end
