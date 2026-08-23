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
    assert_equal "Apple", stale["category"]
    assert_equal subscriptions(:one_stale).id, stale["id"]

    example = subscriptions.find { |subscription| subscription["feed_id"] == feeds(:example).id }
    assert_nil example["category"]
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

  test "update sets a category" do
    subscription = subscriptions(:one_example)

    patch api_subscription_path(subscription),
          params: { subscription: { category: "rails" } },
          as: :json, headers: auth

    assert_response :success
    json = response.parsed_body["subscription"]
    assert_equal "rails", json["category"]
    assert_equal subscription.feed_id, json["feed_id"]
    assert_equal "rails", subscription.reload.category
  end

  test "update clears a category" do
    subscription = subscriptions(:one_stale)

    patch api_subscription_path(subscription),
          params: { subscription: { category: nil } },
          as: :json, headers: auth

    assert_response :success
    assert_nil response.parsed_body.dig("subscription", "category")
    assert_nil subscription.reload.category
  end

  test "update rejects a category that is too long" do
    patch api_subscription_path(subscriptions(:one_example)),
          params: { subscription: { category: "a" * 41 } },
          as: :json, headers: auth

    assert_response :unprocessable_entity
    assert_not_empty response.parsed_body["errors"]
  end

  test "cannot update another user's subscription" do
    patch api_subscription_path(subscriptions(:two_example)),
          params: { subscription: { category: "stolen" } },
          as: :json, headers: auth

    assert_response :not_found
    assert_nil subscriptions(:two_example).reload.category
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token.token}" }
  end
end
