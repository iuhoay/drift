require "test_helper"

class Feed::WatchableTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "notify_watchers_now enqueues one email per watched subscription" do
    feed = feeds(:example)
    subscriptions(:one_example).watch
    subscriptions(:two_example).watch

    assert_enqueued_emails 2 do
      feed.notify_watchers_now([ entries(:example_first).id ])
    end
  end

  test "notify_watchers_now skips subscribers who are not watching" do
    subscriptions(:one_example).watch

    assert_enqueued_emails 1 do
      feeds(:example).notify_watchers_now([ entries(:example_first).id ])
    end
  end

  test "notify_watchers_now no-ops when none of the entry ids exist" do
    subscriptions(:one_example).watch

    assert_no_enqueued_emails do
      feeds(:example).notify_watchers_now([ 0 ])
    end
  end

  test "notify_watchers_later enqueues the job when there are watchers" do
    feed = feeds(:example)
    feed.update!(last_success_at: 1.hour.ago)
    subscriptions(:one_example).watch

    assert_enqueued_with job: WatchNotifyJob, args: [ feed.id, [ 1 ] ] do
      feed.notify_watchers_later([ 1 ])
    end
  end

  test "notify_watchers_later no-ops on the first success" do
    feed = feeds(:example)
    feed.update!(last_success_at: nil)
    subscriptions(:one_example).watch

    assert_no_enqueued_jobs only: WatchNotifyJob do
      feed.notify_watchers_later([ 1 ])
    end
  end

  test "notify_watchers_later no-ops without watchers or ids" do
    feeds(:example).update!(last_success_at: 1.hour.ago)

    assert_no_enqueued_jobs only: WatchNotifyJob do
      feeds(:example).notify_watchers_later([ 1 ])
      feeds(:example).notify_watchers_later([])
    end
  end
end
