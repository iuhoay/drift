require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "signed-out users are sent to sign in" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "non-admin users are denied" do
    sign_in_as users(:one)
    get admin_root_path
    assert_redirected_to root_path
    assert_equal "Access denied", flash[:alert]
  end

  test "admin users see the dashboard" do
    sign_in_as users(:admin)
    get admin_root_path
    assert_response :success
    assert_select "h1, header", text: /admin/i
    assert_select "a[href='/jobs']"
    assert_select "a[href='/rails_pulse']"
    assert_includes @response.body, "// signal"
    assert_includes @response.body, "// recent"
  end

  test "the dashboard surfaces failing feeds with their error" do
    sign_in_as users(:admin)
    get admin_root_path

    assert_response :success
    assert_includes @response.body, "// problem feeds"
    assert_includes @response.body, feeds(:failing).display_title
    assert_includes @response.body, "HTTP 500"
  end

  test "the dashboard flags a dead feed" do
    feeds(:failing).update!(dead_at: 2.days.ago)
    sign_in_as users(:admin)
    get admin_root_path

    assert_response :success
    assert_select "span.bg-red-100", text: /dead/i
  end
end
