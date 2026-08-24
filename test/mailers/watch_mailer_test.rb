require "test_helper"

class WatchMailerTest < ActionMailer::TestCase
  setup do
    @subscription = subscriptions(:one_example)
    @subscription.watch
  end

  test "lists titles and links and points at Feeds to stop watching" do
    entry = entries(:example_first)
    mail = WatchMailer.notify(@subscription, [ entry ])

    assert_equal [ users(:one).email_address ], mail.to
    assert_match "First Example Post", mail.subject
    assert_match "First Example Post", mail.body.encoded
    assert_match "https://example.com/posts/1", mail.body.encoded
    assert_match %r{/entries\?feed_id=#{@subscription.feed_id}}, mail.body.encoded
    assert_match %r{/subscriptions}, mail.body.encoded
  end

  test "is plain text only, no HTML part" do
    mail = WatchMailer.notify(@subscription, [ entries(:example_first) ])

    assert_equal "text/plain", mail.mime_type
    assert_nil mail.html_part
  end

  test "does not send when the subscription is no longer watched" do
    assert_no_emails do
      WatchMailer.notify(subscriptions(:one_stale), [ entries(:stale_first) ]).deliver_now
    end
  end

  test "caps the body and mentions the remainder" do
    entries = 21.times.map do |i|
      @subscription.feed.entries.create!(
        guid: "watch-mail-#{i}",
        title: "Entry #{i}",
        url: "https://example.com/watch/#{i}",
        published_at: Time.current
      )
    end

    mail = WatchMailer.notify(@subscription, entries)
    assert_match "and 1 more", mail.body.encoded
    assert_match "21 new", mail.subject
  end
end
