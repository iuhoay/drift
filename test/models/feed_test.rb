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

  test "due_for_refresh selects feeds older than the interval and never-fetched" do
    fresh = feeds(:unsubscribed)
    stale = feeds(:stale)
    never = Feed.create!(feed_url: "https://never.example.com/feed.xml")

    due = Feed.due_for_refresh(interval: 30.minutes)

    assert_includes due, stale
    assert_includes due, never
    assert_not_includes due, fresh
  end

  test "display_title falls back to feed_url when title is blank" do
    feed = Feed.new(feed_url: "https://example.com/feed.xml", title: "")
    assert_equal "https://example.com/feed.xml", feed.display_title
  end

  test "healthy? reflects fetch_failure_count" do
    assert feeds(:example).healthy?
    assert_not feeds(:failing).healthy?
  end
end
