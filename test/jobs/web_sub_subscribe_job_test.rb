require "test_helper"

class WebSubSubscribeJobTest < ActiveJob::TestCase
  test "is enqueued on the default queue" do
    assert_enqueued_with(job: WebSubSubscribeJob, queue: "default", args: [ feeds(:youtube_pending).id ]) do
      WebSubSubscribeJob.perform_later(feeds(:youtube_pending).id)
    end
  end

  test "performing with a missing feed is a no-op" do
    assert_nothing_raised do
      WebSubSubscribeJob.perform_now(0)
    end
  end
end
