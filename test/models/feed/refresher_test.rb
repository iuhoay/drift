require "test_helper"

class Feed::RefresherTest < ActiveSupport::TestCase
  # A minimal Atom feed so the 200 path parses and upserts an entry.
  FEED_BODY = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Recovered Feed</title>
      <link href="https://example.com"/>
      <entry>
        <id>urn:entry:1</id>
        <title>Hello</title>
        <link href="https://example.com/1"/>
      </entry>
    </feed>
  XML

  test "a failure backs off, increments the count, and is not yet dead" do
    feed = feeds(:example)

    Feed::Refresher.new(feed, http: stub_http(500)).call
    feed.reload

    assert_equal 1, feed.fetch_failure_count
    assert_equal "HTTP 500", feed.last_error
    assert_not feed.dead?
    assert_operator feed.next_fetch_at, :>, Time.current
  end

  test "crossing the failure threshold marks the feed dead" do
    feed = feeds(:example)
    feed.update!(fetch_failure_count: Feed::DEAD_AFTER_FAILURES - 1)

    Feed::Refresher.new(feed, http: stub_http(404)).call
    feed.reload

    assert_equal Feed::DEAD_AFTER_FAILURES, feed.fetch_failure_count
    assert feed.dead?
  end

  test "honors Retry-After on a 429" do
    feed = feeds(:example)

    Feed::Refresher.new(feed, http: stub_http(429, "Retry-After" => "300")).call
    feed.reload

    assert_in_delta 300, feed.next_fetch_at - Time.current, 5
  end

  test "a success revives a dead feed and clears its error" do
    feed = feeds(:failing)
    feed.update!(fetch_failure_count: Feed::DEAD_AFTER_FAILURES, dead_at: 2.days.ago)

    Feed::Refresher.new(feed, http: stub_http(200, {}, FEED_BODY)).call
    feed.reload

    assert_not feed.dead?
    assert_equal 0, feed.fetch_failure_count
    assert_nil feed.last_error
    assert feed.entries.exists?(title: "Hello")
  end

  private

  def stub_http(status, headers = {}, body = "")
    Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get(//) { [ status, headers, body ] }
      end
    end
  end
end
