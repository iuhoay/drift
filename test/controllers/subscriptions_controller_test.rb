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
    assert_select "form[action=?]", subscription_watch_path(subscriptions(:one_example))
    assert_select "p", /Watch a feed/
  end

  test "index groups categorized feeds and links the bucket" do
    get subscriptions_path
    assert_response :success

    assert_select "a[href=?]", entries_path(category: "Apple", scope: "unread"), text: "Apple"
    assert_select "input[name='subscription[category]']"
    assert_select "input[type=submit][value=Save]", count: 0
    assert_select "[data-controller=category-combobox]"
    assert_select "[role=listbox]"
    assert_select "[role=option][data-value=Apple]", text: "Apple"
  end

  test "new" do
    get new_subscription_path
    assert_response :success
  end

  test "new offers existing categories as chips" do
    get new_subscription_path
    assert_response :success
    assert_select "button[data-category-combobox-target=chip]", text: "Apple"
    assert_select "input[name='subscription[category]']"
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

  test "update changes the category" do
    subscription = subscriptions(:one_example)

    patch subscription_path(subscription), params: { subscription: { category: "rails" } }

    assert_redirected_to subscriptions_path
    assert_equal "rails", subscription.reload.category
  end

  test "update adopts the casing of an existing category" do
    subscription = subscriptions(:one_example)

    patch subscription_path(subscription), params: { subscription: { category: "apple" } }

    assert_redirected_to subscriptions_path
    assert_equal "Apple", subscription.reload.category
  end

  test "update clears the category when blank" do
    subscription = subscriptions(:one_stale)

    patch subscription_path(subscription), params: { subscription: { category: "  " } }

    assert_redirected_to subscriptions_path
    assert_nil subscription.reload.category
  end

  test "update with a too-long category redirects with an alert" do
    subscription = subscriptions(:one_example)

    patch subscription_path(subscription), params: { subscription: { category: "a" * 41 } }

    assert_redirected_to subscriptions_path
    assert_nil subscription.reload.category
    assert_match(/too long/, flash[:alert])
  end

  test "update via turbo stream swaps the list in place" do
    subscription = subscriptions(:one_example)

    patch subscription_path(subscription),
          params: { subscription: { category: "rails" } },
          as: :turbo_stream

    assert_response :success
    assert_equal "rails", subscription.reload.category
    assert_match %r{turbo-stream[^>]*target="subscriptions"}, @response.body
    assert_match %r{turbo-stream[^>]*target="sidebar-feeds"}, @response.body
    assert_includes @response.body, "rails"
  end

  test "update via turbo stream surfaces a validation alert" do
    patch subscription_path(subscriptions(:one_example)),
          params: { subscription: { category: "a" * 41 } },
          as: :turbo_stream

    assert_response :success
    assert_nil subscriptions(:one_example).reload.category
    assert_match %r{turbo-stream action="update" target="flash"}, @response.body
    assert_match(/too long/, @response.body)
  end

  test "create stores category" do
    existing = feeds(:unsubscribed)

    post subscriptions_path, params: { subscription: { feed_url: existing.feed_url, category: "news" } }

    assert_redirected_to subscriptions_path
    assert_equal "news", @user.subscriptions.find_by!(feed: existing).category
  end

  test "create adopts the casing of an existing category" do
    existing = feeds(:unsubscribed)

    post subscriptions_path, params: { subscription: { feed_url: existing.feed_url, category: "apple" } }

    assert_redirected_to subscriptions_path
    assert_equal "Apple", @user.subscriptions.find_by!(feed: existing).category
  end

  test "destroy removes the subscription" do
    subscription = subscriptions(:one_example)

    assert_difference -> { Subscription.count } => -1 do
      delete subscription_path(subscription)
    end

    assert_redirected_to subscriptions_path
  end

  test "destroy via turbo stream removes the row in place" do
    subscription = subscriptions(:one_example)

    assert_difference -> { Subscription.count } => -1 do
      delete subscription_path(subscription), as: :turbo_stream
    end

    assert_response :success
    assert_match %r{turbo-stream[^>]*target="subscriptions"}, @response.body
    assert_includes @response.body, "Unsubscribed"
  end

  test "cannot destroy another user's subscription" do
    other = subscriptions(:two_example)

    assert_no_difference -> { Subscription.count } do
      delete subscription_path(other)
    end

    assert_response :not_found
  end
end
