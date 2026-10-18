require "test_helper"

class Subscriptions::WatchesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = users(:one)
    @subscription = subscriptions(:one_example)
    sign_in_as(@user)
  end

  test "create via turbo stream replaces the button in place" do
    post subscription_watch_path(@subscription), as: :turbo_stream

    assert_response :success
    assert @subscription.reload.watched?
    assert_match %r{turbo-stream[^>]*action="replace"[^>]*target="#{dom_id(@subscription, :watch)}"}, @response.body
    assert_match(/aria-pressed="true"/, @response.body)
  end

  test "destroy via turbo stream replaces the button in place" do
    @subscription.watch

    delete subscription_watch_path(@subscription), as: :turbo_stream

    assert_response :success
    assert_not @subscription.reload.watched?
    assert_match(/aria-pressed="false"/, @response.body)
  end

  test "html create without a referer falls back to feeds" do
    post subscription_watch_path(@subscription)

    assert_redirected_to subscriptions_path
    assert @subscription.reload.watched?
  end

  test "html create from the feed inbox returns there" do
    inbox = entries_url(feed_id: @subscription.feed_id, scope: "unread")

    post subscription_watch_path(@subscription), headers: { "HTTP_REFERER" => inbox }

    assert_redirected_to inbox
    assert @subscription.reload.watched?
  end

  test "cannot watch another user's subscription" do
    post subscription_watch_path(subscriptions(:two_example))

    assert_response :not_found
    assert_not subscriptions(:two_example).reload.watched?
  end
end
