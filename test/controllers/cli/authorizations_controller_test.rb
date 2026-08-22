require "test_helper"

class Cli::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @redirect_uri = "http://127.0.0.1:12345/callback"
    @state = "cli-state-token"
  end

  test "requires authentication and keeps the authorize URL as return_to" do
    get new_cli_authorization_path, params: { redirect_uri: @redirect_uri, state: @state }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
  end

  test "oauth sign-in returns to the authorize page" do
    OmniAuth.config.test_mode = true
    identity = identities(:two_github)
    auth = OmniAuth::AuthHash.new(
      provider: "github",
      uid: identity.uid,
      info: { email: identity.user.email_address },
      extra: { raw_info: { email_verified: true } }
    )
    OmniAuth.config.mock_auth[:github] = auth
    Rails.application.env_config["omniauth.auth"] = auth

    get new_cli_authorization_path, params: { redirect_uri: @redirect_uri, state: @state }
    assert_redirected_to new_session_path

    get "/auth/github/callback"
    assert_redirected_to new_cli_authorization_url(redirect_uri: @redirect_uri, state: @state)
  ensure
    OmniAuth.config.mock_auth.clear
    Rails.application.env_config.delete("omniauth.auth")
    OmniAuth.config.test_mode = false
  end

  test "GET is a confirm page and does not mint a grant or token" do
    sign_in_as(@user)

    assert_no_difference -> { CliAuthorization.count } do
      assert_no_difference -> { @user.api_tokens.count } do
        get new_cli_authorization_path, params: { redirect_uri: @redirect_uri, state: @state }
      end
    end

    assert_response :success
    assert_select "form[action=?][data-turbo=false]", cli_authorizations_path
    assert_select "input[name=redirect_uri][value=?]", @redirect_uri
    assert_select "input[name=state][value=?]", @state
    assert_select "aside", count: 0
    assert_select "nav", count: 0
  end

  test "GET rejects a non-loopback redirect" do
    sign_in_as(@user)

    get new_cli_authorization_path, params: { redirect_uri: "https://evil.example/callback", state: @state }

    assert_response :unprocessable_entity
    assert_select "h1", text: /invalid/i
  end

  test "POST mints a grant and redirects to loopback with a code, not a token" do
    sign_in_as(@user)

    assert_difference -> { CliAuthorization.count } => 1 do
      assert_no_difference -> { @user.api_tokens.count } do
        post cli_authorizations_path, params: { redirect_uri: @redirect_uri, state: @state }
      end
    end

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "127.0.0.1", location.host
    query = Rack::Utils.parse_query(location.query)
    assert_equal @state, query["state"]
    assert query["code"].present?
    assert_nil query["token"]
    assert_equal CliAuthorization.last.code, query["code"]
  end

  test "POST rejects a non-loopback redirect" do
    sign_in_as(@user)

    assert_no_difference -> { CliAuthorization.count } do
      post cli_authorizations_path, params: { redirect_uri: "http://example.com/callback", state: @state }
    end

    assert_response :unprocessable_entity
  end
end
