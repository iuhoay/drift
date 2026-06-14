require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "about is reachable without authentication" do
    get about_path
    assert_response :success
    assert_select "h1", "About Drift"
  end

  test "terms is reachable without authentication" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "privacy is reachable without authentication" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "sign-up links to the legal pages" do
    get new_registration_path
    assert_response :success
    assert_select "a[href=?]", terms_path
    assert_select "a[href=?]", privacy_path
  end
end
