require "test_helper"

class Account::ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get account_api_tokens_path
    assert_redirected_to new_session_path
  end

  test "index lists the user's tokens" do
    get account_api_tokens_path
    assert_response :success
    assert_select "##{dom_id(api_tokens(:one_laptop))}"
    assert_select "##{dom_id(api_tokens(:two_laptop))}", false
  end

  test "create generates a token and reveals it once via turbo stream" do
    assert_difference -> { @user.api_tokens.count } => 1 do
      post account_api_tokens_path, params: { api_token: { name: "Phone" } }, as: :turbo_stream
    end

    assert_response :success
    created = @user.api_tokens.order(:created_at).last
    assert_match %r{turbo-stream action="update" target="token_manager"}, @response.body
    assert_includes @response.body, created.token
  end

  test "create falls back to a redirect for non-turbo clients" do
    post account_api_tokens_path, params: { api_token: { name: "Phone" } }
    assert_redirected_to account_api_tokens_path
  end

  test "destroy revokes a token" do
    assert_difference -> { @user.api_tokens.count } => -1 do
      delete account_api_token_path(api_tokens(:one_laptop))
    end

    assert_redirected_to account_api_tokens_path
  end

  test "cannot revoke another user's token" do
    assert_no_difference -> { ApiToken.count } do
      delete account_api_token_path(api_tokens(:two_laptop))
    end

    assert_response :not_found
  end
end
