require "test_helper"

class Sessions::OmniauthControllerTest < ActionDispatch::IntegrationTest
  setup { OmniAuth.config.test_mode = true }

  teardown do
    OmniAuth.config.mock_auth.clear
    Rails.application.env_config.delete("omniauth.auth")
    OmniAuth.config.test_mode = false
  end

  test "signs in via an existing identity without creating a user" do
    identity = identities(:two_github)

    assert_no_difference -> { User.count } do
      callback "github", uid: identity.uid, email: "anything@example.com"
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "auto-links a verified provider email to an existing user" do
    user = users(:one)

    assert_difference -> { Identity.count } => 1, -> { User.count } => 0 do
      callback "github", uid: "fresh-github-uid", email: user.email_address
    end

    assert_redirected_to root_path
    assert_equal user, Identity.find_by(provider: "github", uid: "fresh-github-uid").user
  end

  test "creates a new verified user when nothing matches" do
    assert_difference -> { User.count } => 1, -> { Identity.count } => 1 do
      callback "github", uid: "brand-new-uid", email: "brand-new@example.com"
    end

    assert_redirected_to root_path
    assert User.find_by(email_address: "brand-new@example.com").verified?
  end

  test "does not auto-link when the provider email is unverified" do
    assert_no_difference -> { Identity.count } do
      callback "google_oauth2", uid: "google-uid", email: users(:one).email_address, email_verified: false
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "rejects sign-in when the provider shares no email" do
    assert_no_difference -> { User.count } do
      callback "github", uid: "no-email-uid", email: nil
    end

    assert_redirected_to new_session_path
  end

  test "links a provider to the already signed-in user" do
    sign_in_as users(:one)

    assert_difference -> { users(:one).identities.count } => 1 do
      callback "github", uid: "link-while-signed-in", email: "ignored@example.com"
    end

    assert_redirected_to account_path
  end

  test "callback without auth data redirects with an error" do
    get "/auth/github/callback"
    assert_redirected_to new_session_path
  end

  test "failure redirects to sign in" do
    get "/auth/failure"
    assert_redirected_to new_session_path
  end

  private
    def callback(provider, uid:, email:, email_verified: true)
      auth = OmniAuth::AuthHash.new(
        provider: provider.to_s,
        uid: uid,
        info: { email: email },
        extra: { raw_info: { email_verified: email_verified } }
      )
      OmniAuth.config.mock_auth[provider.to_sym] = auth
      Rails.application.env_config["omniauth.auth"] = auth
      get "/auth/#{provider}/callback"
    end
end
