require "test_helper"

class FeedRefreshJobTest < ActiveJob::TestCase
  test "is enqueued on the default queue" do
    assert_enqueued_with(job: FeedRefreshJob, queue: "default", args: [ feeds(:example).id ]) do
      FeedRefreshJob.perform_later(feeds(:example).id)
    end
  end

  test "performing with a missing feed is a no-op" do
    assert_nothing_raised do
      FeedRefreshJob.perform_now(0)
    end
  end
end
