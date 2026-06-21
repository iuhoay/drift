require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors see the landing page" do
    get root_path
    assert_response :success

    assert_select "h1", "A calm place to read the web."
    assert_select "a[href=?]", new_registration_path
    assert_select "a[href=?]", new_session_path
  end

  test "landing page links to the legal pages" do
    get root_path
    assert_response :success

    assert_select "a[href=?]", about_path
    assert_select "a[href=?]", terms_path
    assert_select "a[href=?]", privacy_path
  end

  test "signed-in readers are redirected to their inbox" do
    sign_in_as(users(:one))
    get root_path
    assert_redirected_to entries_path
  end
end
