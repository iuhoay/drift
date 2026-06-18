require "test_helper"

class FeedTest < ActiveSupport::TestCase
  test "strips feed_url" do
    feed = Feed.new(feed_url: "  https://example.com/new.xml  ")
    assert_equal "https://example.com/new.xml", feed.feed_url
  end

  test "requires an http(s) feed_url" do
    feed = Feed.new(feed_url: "ftp://example.com/feed.xml")

    assert_not feed.valid?
    assert_includes feed.errors[:feed_url], "is invalid"
  end

  test "rejects duplicate feed_url case-insensitively" do
    duplicate = Feed.new(feed_url: "HTTPS://example.com/feed.xml")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:feed_url], "has already been taken"
  end

  test "due_for_refresh selects feeds past next_fetch_at and never-fetched" do
    fresh = feeds(:unsubscribed)
    stale = feeds(:stale)
    never = Feed.create!(feed_url: "https://never.example.com/feed.xml")

    due = Feed.due_for_refresh

    assert_includes due, stale
    assert_includes due, never
    assert_not_includes due, fresh
  end

  test "youtube? recognizes youtube channel feeds" do
    assert Feed.new(feed_url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC123").youtube?
    assert Feed.new(feed_url: "http://youtube.com/feeds/videos.xml?channel_id=UC123").youtube?
    assert_not Feed.new(feed_url: "https://example.com/youtube.com/feed.xml").youtube?
    assert_not Feed.new(feed_url: "https://notyoutube.com/feed.xml").youtube?
  end

  test "refresh_interval is longer for youtube feeds" do
    youtube = Feed.new(feed_url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC123")
    assert_equal Feed::YOUTUBE_REFRESH_INTERVAL, youtube.refresh_interval
    assert_equal Feed::REFRESH_INTERVAL, feeds(:example).refresh_interval
  end

  test "refresh_interval drops to the websub interval when a push subscription is active" do
    assert feeds(:youtube).web_sub_subscription.active?
    assert_equal Feed::WEBSUB_REFRESH_INTERVAL, feeds(:youtube).refresh_interval
  end

  test "backoff_interval grows exponentially and is capped" do
    feed = feeds(:example)
    base = feed.refresh_interval.to_i

    assert_equal base, feed.backoff_interval(1)
    assert_equal base * 2, feed.backoff_interval(2)
    assert_equal base * 4, feed.backoff_interval(3)
    assert_equal Feed::MAX_BACKOFF.to_i, feed.backoff_interval(99)
  end

  test "backoff_interval honors a numeric Retry-After over exponential backoff" do
    assert_equal 120, feeds(:example).backoff_interval(5, retry_after: "120")
  end

  test "backoff_interval honors an http-date Retry-After" do
    retry_at = 10.minutes.from_now
    seconds = feeds(:example).backoff_interval(1, retry_after: retry_at.httpdate)

    assert_in_delta 600, seconds, 2
  end

  test "backoff_interval ignores a blank or past Retry-After and falls back to backoff" do
    feed = feeds(:example)
    base = feed.refresh_interval.to_i

    assert_equal base, feed.backoff_interval(1, retry_after: nil)
    assert_equal base, feed.backoff_interval(1, retry_after: 1.hour.ago.httpdate)
  end

  test "dead_at_after marks dead only once the failure threshold is crossed" do
    feed = feeds(:example)
    now = Time.current

    assert_nil feed.dead_at_after(Feed::DEAD_AFTER_FAILURES - 1, now: now)
    assert_equal now, feed.dead_at_after(Feed::DEAD_AFTER_FAILURES, now: now)
  end

  test "dead_at_after preserves the first dead_at once set" do
    feed = feeds(:example)
    feed.dead_at = 3.days.ago

    # Compare against the stored value: assigning to the datetime attribute truncates
    # to the column's microsecond precision, while a raw Time keeps nanoseconds.
    assert_equal feed.dead_at, feed.dead_at_after(Feed::DEAD_AFTER_FAILURES + 5, now: Time.current)
  end

  test "dead? and dead/alive scopes reflect dead_at" do
    feeds(:failing).update!(dead_at: 1.day.ago)

    assert feeds(:failing).reload.dead?
    assert_not feeds(:example).dead?
    assert_includes Feed.dead, feeds(:failing)
    assert_includes Feed.alive, feeds(:example)
    assert_not_includes Feed.alive, feeds(:failing)
  end

  test "failing scope selects feeds with at least one failure" do
    assert_includes Feed.failing, feeds(:failing)
    assert_not_includes Feed.failing, feeds(:example)
  end

  test "youtube scope matches youtube channel feeds by url" do
    youtube = Feed.create!(feed_url: "https://www.youtube.com/feeds/videos.xml?channel_id=UC123")

    assert_includes Feed.youtube, youtube
    assert_not_includes Feed.youtube, feeds(:example)
  end

  test "troubled scope leads with dead feeds and carries subscriber counts" do
    feeds(:failing).update!(dead_at: 1.day.ago)
    feeds(:example).update!(fetch_failure_count: 1)

    troubled = Feed.troubled.to_a

    assert_equal feeds(:failing), troubled.first
    example_row = troubled.find { |feed| feed == feeds(:example) }
    assert_equal feeds(:example).subscriptions.count, example_row.subscribers_count.to_i
  end

  test "display_title falls back to feed_url when title is blank" do
    feed = Feed.new(feed_url: "https://example.com/feed.xml", title: "")
    assert_equal "https://example.com/feed.xml", feed.display_title
  end

  test "healthy? reflects fetch_failure_count" do
    assert feeds(:example).healthy?
    assert_not feeds(:failing).healthy?
  end

  test "USER_AGENT tags the environment outside production" do
    assert_not_equal "Drift RSS Reader/0.1 (+https://rdrift.app)", Feed::USER_AGENT
    assert_includes Feed::USER_AGENT, Rails.env
  end

  test "resolve_url returns a tracked feed url as-is without discovery" do
    tracked = feeds(:example).feed_url

    resolved = stub_discovery([]) do
      Feed.resolve_url(tracked)
    end

    assert_equal tracked, resolved
  end

  test "resolve_url strips the address before matching a tracked feed" do
    resolved = stub_discovery([]) do
      Feed.resolve_url("  #{feeds(:example).feed_url}  ")
    end

    assert_equal feeds(:example).feed_url, resolved
  end

  test "resolve_url delegates to discovery for an unknown address" do
    feed_url = "https://discovered.example.com/atom.xml"

    resolved = stub_discovery([ feed_url ]) do
      Feed.resolve_url("https://discovered.example.com")
    end

    assert_equal feed_url, resolved
  end

  test "resolve_url returns nil when nothing resolves to a feed" do
    resolved = stub_discovery([]) do
      Feed.resolve_url("https://no-feed.example.com")
    end

    assert_nil resolved
  end
end
