require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "show renders the account settings" do
    get account_path
    assert_response :success
    assert_select "h1", text: "Account"
  end

  test "show requires authentication" do
    sign_out
    get account_path
    assert_redirected_to new_session_path
  end

  test "destroy deletes the account and signs out" do
    assert_difference -> { User.count } => -1 do
      delete account_path
    end

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
