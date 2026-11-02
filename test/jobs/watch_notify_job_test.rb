require "test_helper"

class WatchNotifyJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "is enqueued on the default queue" do
    assert_enqueued_with(job: WatchNotifyJob, queue: "default", args: [ feeds(:example).id, [ 1 ] ]) do
      WatchNotifyJob.perform_later(feeds(:example).id, [ 1 ])
    end
  end

  test "performing with a missing feed is a no-op" do
    assert_nothing_raised do
      WatchNotifyJob.perform_now(0, [ 1 ])
    end
  end

  test "performing delivers to current watchers" do
    subscriptions(:one_example).watch

    assert_enqueued_emails 1 do
      WatchNotifyJob.perform_now(feeds(:example).id, [ entries(:example_first).id ])
    end
  end
end
