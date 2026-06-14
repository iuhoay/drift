require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get subscriptions_path
    assert_redirected_to new_session_path
  end

  test "index lists the user's subscriptions" do
    get subscriptions_path
    assert_response :success
  end

  test "new" do
    get new_subscription_path
    assert_response :success
  end

  test "create reuses an existing feed and enqueues a refresh" do
    existing = feeds(:unsubscribed)

    assert_difference -> { @user.subscriptions.count } => 1, -> { Feed.count } => 0 do
      assert_enqueued_with(job: FeedRefreshJob, args: [ existing.id ]) do
        post subscriptions_path, params: { subscription: { feed_url: existing.feed_url } }
      end
    end

    assert_redirected_to subscriptions_path
  end

  test "create creates a new feed when needed" do
    feed_url = "https://brand-new.example.com/feed.xml"

    stub_discovery([ feed_url ]) do
      assert_difference -> { Feed.count } => 1, -> { @user.subscriptions.count } => 1 do
        post subscriptions_path, params: { subscription: { feed_url: feed_url } }
      end
    end

    assert_redirected_to subscriptions_path
  end

  test "create auto-detects the feed url from a site address" do
    site_url = "https://www.ruanyifeng.com/blog/"
    feed_url = "https://www.ruanyifeng.com/blog/atom.xml"

    stub_discovery([ feed_url ]) do
      assert_difference -> { Feed.count } => 1 do
        post subscriptions_path, params: { subscription: { feed_url: site_url } }
      end
    end

    assert_redirected_to subscriptions_path
    assert_equal feed_url, Feed.last.feed_url
  end

  test "create re-renders when no feed can be detected" do
    stub_discovery([]) do
      assert_no_difference -> { Subscription.count } do
        post subscriptions_path, params: { subscription: { feed_url: "https://no-feed.example.com" } }
      end
    end

    assert_response :unprocessable_entity
  end

  test "create with blank feed_url re-renders" do
    assert_no_difference -> { Subscription.count } do
      post subscriptions_path, params: { subscription: { feed_url: "  " } }
    end

    assert_response :unprocessable_entity
  end

  test "create with invalid feed_url re-renders" do
    assert_no_difference -> { Subscription.count } do
      post subscriptions_path, params: { subscription: { feed_url: "not-a-url" } }
    end

    assert_response :unprocessable_entity
  end

  test "update changes the custom_title" do
    subscription = subscriptions(:one_example)

    patch subscription_path(subscription), params: { subscription: { custom_title: "Renamed" } }

    assert_redirected_to subscriptions_path
    assert_equal "Renamed", subscription.reload.custom_title
  end

  test "destroy removes the subscription" do
    subscription = subscriptions(:one_example)

    assert_difference -> { Subscription.count } => -1 do
      delete subscription_path(subscription)
    end

    assert_redirected_to subscriptions_path
  end

  test "cannot destroy another user's subscription" do
    other = subscriptions(:two_example)

    assert_no_difference -> { Subscription.count } do
      delete subscription_path(other)
    end

    assert_response :not_found
  end

  private

  # Replaces Feed::Discovery.call with a canned result for the block so the
  # controller never reaches out to the network during the test.
  def stub_discovery(result)
    original = Feed::Discovery.method(:call)
    Feed::Discovery.define_singleton_method(:call) { |_url| result }
    yield
  ensure
    Feed::Discovery.define_singleton_method(:call, original)
  end
end
