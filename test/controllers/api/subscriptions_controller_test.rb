require "test_helper"

class Api::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = api_tokens(:one_laptop)
  end

  test "rejects a request with no token" do
    get api_subscriptions_path, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "rejects an unknown token" do
    get api_subscriptions_path, as: :json, headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "lists the token owner's subscriptions with custom titles" do
    get api_subscriptions_path, as: :json, headers: auth
    assert_response :success

    subscriptions = response.parsed_body["subscriptions"]
    feed_ids = subscriptions.map { |subscription| subscription["feed_id"] }
    assert_includes feed_ids, feeds(:example).id
    assert_includes feed_ids, feeds(:stale).id

    stale = subscriptions.find { |subscription| subscription["feed_id"] == feeds(:stale).id }
    assert_equal "My Stale Feed", stale["title"]
    assert_equal feeds(:stale).feed_url, stale["feed_url"]
  end

  test "another user's token does not see this user's only-one feeds" do
    get api_subscriptions_path, as: :json,
        headers: { "Authorization" => "Bearer #{api_tokens(:two_laptop).token}" }
    assert_response :success

    feed_ids = response.parsed_body["subscriptions"].map { |subscription| subscription["feed_id"] }
    assert_includes feed_ids, feeds(:example).id
    assert_not_includes feed_ids, feeds(:stale).id
    assert_not_includes feed_ids, feeds(:unsubscribed).id
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token.token}" }
  end
end
