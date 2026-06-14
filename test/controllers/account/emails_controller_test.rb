require "test_helper"

class Account::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "edit renders" do
    get edit_account_email_path
    assert_response :success
  end

  test "update changes the email and resets verification" do
    patch account_email_path, params: { user: { email_address: "new-one@example.com" } }

    assert_redirected_to account_path
    user = users(:one).reload
    assert_equal "new-one@example.com", user.email_address
    assert_not user.verified?
  end

  test "update with the same email keeps verification" do
    patch account_email_path, params: { user: { email_address: users(:one).email_address } }

    assert_redirected_to account_path
    assert users(:one).reload.verified?
  end

  test "update with an invalid email re-renders" do
    patch account_email_path, params: { user: { email_address: "nope" } }

    assert_response :unprocessable_entity
    assert_equal "one@example.com", users(:one).reload.email_address
  end
end
