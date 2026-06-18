require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "is unique per user and feed" do
    duplicate = users(:one).subscriptions.build(feed: feeds(:example))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "different users may subscribe to the same feed" do
    new_user = User.create!(email_address: "new@example.com", password: "password1")
    subscription = new_user.subscriptions.build(feed: feeds(:example))
    assert subscription.valid?
  end

  test "display_title prefers custom_title, then feed title" do
    custom = subscriptions(:one_stale)
    assert_equal "My Stale Feed", custom.display_title

    plain = subscriptions(:one_example)
    assert_equal feeds(:example).title, plain.display_title
  end

  test "subscribe creates the feed and subscription and enqueues a refresh" do
    user = users(:two)
    feed_url = "https://brand-new.example.com/feed.xml"

    subscription = stub_discovery([ feed_url ]) do
      assert_difference -> { Feed.count } => 1, -> { user.subscriptions.count } => 1 do
        Subscription.subscribe(user, feed_url)
      end
    end

    assert subscription.persisted?
    assert_equal feed_url, subscription.feed.feed_url
    assert_enqueued_with job: FeedRefreshJob, args: [ subscription.feed.id ]
  end

  test "subscribe reuses an already-tracked feed without discovery" do
    user = users(:two)
    feed = feeds(:stale)

    # Returning [] from discovery would fail resolution; a persisted result
    # proves the tracked-URL short-circuit ran instead of hitting the network.
    subscription = stub_discovery([]) do
      assert_difference -> { user.subscriptions.count } => 1, -> { Feed.count } => 0 do
        Subscription.subscribe(user, feed.feed_url)
      end
    end

    assert_equal feed, subscription.feed
  end

  test "subscribe is idempotent for an existing subscription" do
    existing = subscriptions(:one_example)

    result = stub_discovery([]) do
      assert_no_difference -> { Subscription.count } do
        Subscription.subscribe(users(:one), feeds(:example).feed_url)
      end
    end

    assert_equal existing, result
  end

  test "subscribe stores a custom_title when given, leaving it nil when blank" do
    user = users(:two)

    titled = stub_discovery([ "https://titled.example.com/feed.xml" ]) do
      Subscription.subscribe(user, "https://titled.example.com/feed.xml", custom_title: "My Title")
    end
    assert_equal "My Title", titled.custom_title

    untitled = stub_discovery([ "https://untitled.example.com/feed.xml" ]) do
      Subscription.subscribe(user, "https://untitled.example.com/feed.xml", custom_title: "  ")
    end
    assert_nil untitled.custom_title
  end

  test "subscribe with a blank address returns an unsaved subscription with an error" do
    subscription = assert_no_difference -> { Subscription.count } do
      Subscription.subscribe(users(:two), "   ")
    end

    assert_not subscription.persisted?
    assert_includes subscription.errors[:feed_url], "can't be blank"
  end

  test "subscribe returns an error when no feed can be resolved" do
    subscription = stub_discovery([]) do
      assert_no_difference -> { Subscription.count } do
        Subscription.subscribe(users(:two), "https://no-feed.example.com")
      end
    end

    assert_not subscription.persisted?
    assert_includes subscription.errors[:feed_url], "no feed found at that address"
  end
end
