require "test_helper"

class Account::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "edit renders" do
    get edit_account_password_path
    assert_response :success
  end

  test "update with the correct current password changes it" do
    patch account_password_path, params: {
      current_password: "password",
      user: { password: "newpassword1", password_confirmation: "newpassword1" }
    }

    assert_redirected_to account_path
    assert users(:one).reload.authenticate("newpassword1")
  end

  test "update with the wrong current password is rejected" do
    patch account_password_path, params: {
      current_password: "wrong",
      user: { password: "newpassword1", password_confirmation: "newpassword1" }
    }

    assert_response :unprocessable_entity
    assert users(:one).reload.authenticate("password")
  end

  test "update with a mismatched confirmation re-renders" do
    patch account_password_path, params: {
      current_password: "password",
      user: { password: "newpassword1", password_confirmation: "different1" }
    }

    assert_response :unprocessable_entity
    assert users(:one).reload.authenticate("password")
  end
end
