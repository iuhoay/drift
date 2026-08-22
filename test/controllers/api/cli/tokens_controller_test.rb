require "test_helper"

class Api::Cli::TokensControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "exchanges a fresh code for an API token" do
    grant = @user.cli_authorizations.create!(expires_at: 5.minutes.from_now)

    assert_difference -> { @user.api_tokens.count } => 1 do
      post api_cli_token_path, params: { code: grant.code }, as: :json
    end

    assert_response :created
    token = response.parsed_body["token"]
    assert_equal @user.api_tokens.order(:id).last.token, token

    get api_entries_path, as: :json, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
  end

  test "rejects a missing code" do
    post api_cli_token_path, params: { code: "" }, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "rejects a second exchange of the same code" do
    grant = @user.cli_authorizations.create!(expires_at: 5.minutes.from_now)

    post api_cli_token_path, params: { code: grant.code }, as: :json
    assert_response :created

    assert_no_difference -> { @user.api_tokens.count } do
      post api_cli_token_path, params: { code: grant.code }, as: :json
    end

    assert_response :unauthorized
  end

  test "rejects an expired code" do
    grant = @user.cli_authorizations.create!(expires_at: 1.minute.ago)

    assert_no_difference -> { @user.api_tokens.count } do
      post api_cli_token_path, params: { code: grant.code }, as: :json
    end

    assert_response :unauthorized
  end
end
