require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  test "show verifies via a valid token while signed out" do
    user = users(:unverified)
    get email_verification_path(user.generate_token_for(:email_verification))

    assert_redirected_to new_session_path
    assert user.reload.verified?
  end

  test "show with an invalid token does not verify" do
    user = users(:unverified)
    get email_verification_path("garbage")

    assert_redirected_to new_session_path
    assert_not user.reload.verified?
  end

  test "show redirects a signed-in user to the account page" do
    user = users(:unverified)
    sign_in_as user
    get email_verification_path(user.generate_token_for(:email_verification))

    assert_redirected_to account_path
    assert user.reload.verified?
  end

  test "create resends verification for the signed-in user" do
    sign_in_as users(:unverified)
    post email_verifications_path

    assert_redirected_to account_path
    assert_equal "Verification email sent. Check your inbox.", flash[:notice]
  end

  test "create is a no-op when already verified" do
    sign_in_as users(:one)
    post email_verifications_path

    assert_redirected_to account_path
    assert_equal "Your email is already verified.", flash[:notice]
  end

  test "create requires authentication" do
    post email_verifications_path
    assert_redirected_to new_session_path
  end
end
