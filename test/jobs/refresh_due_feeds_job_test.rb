require "test_helper"

class RefreshDueFeedsJobTest < ActiveJob::TestCase
  test "enqueues a FeedRefreshJob for every due feed" do
    Feed.update_all(next_fetch_at: 30.minutes.from_now)
    feeds(:stale).update!(next_fetch_at: 1.minute.ago)
    feeds(:failing).update!(next_fetch_at: nil)

    assert_enqueued_jobs 2, only: FeedRefreshJob do
      RefreshDueFeedsJob.perform_now
    end

    expected_ids = [ feeds(:stale).id, feeds(:failing).id ].sort
    enqueued_ids = enqueued_jobs.select { |j| j[:job] == FeedRefreshJob }.map { |j| j[:args].first }.sort
    assert_equal expected_ids, enqueued_ids
  end
end
