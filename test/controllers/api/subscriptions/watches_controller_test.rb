require "test_helper"

class Api::Subscriptions::WatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = api_tokens(:one_laptop)
    @subscription = subscriptions(:one_example)
  end

  test "create turns watch on" do
    post api_subscription_watch_path(@subscription), as: :json, headers: auth

    assert_response :success
    assert_equal true, response.parsed_body.dig("subscription", "watched")
    assert @subscription.reload.watched?
  end

  test "destroy turns watch off" do
    @subscription.watch

    delete api_subscription_watch_path(@subscription), as: :json, headers: auth

    assert_response :success
    assert_equal false, response.parsed_body.dig("subscription", "watched")
    assert_not @subscription.reload.watched?
  end

  test "cannot watch another user's subscription" do
    post api_subscription_watch_path(subscriptions(:two_example)), as: :json, headers: auth

    assert_response :not_found
    assert_not subscriptions(:two_example).reload.watched?
  end

  test "rejects a request with no token" do
    post api_subscription_watch_path(@subscription), as: :json
    assert_response :unauthorized
  end

  private
    def auth
      { "Authorization" => "Bearer #{@token.token}" }
    end
end
