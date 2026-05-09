require "test_helper"

class RefreshDueFeedsJobTest < ActiveJob::TestCase
  test "enqueues a FeedRefreshJob for every due feed" do
    Feed.update_all(last_fetched_at: 1.minute.ago)
    feeds(:stale).update!(last_fetched_at: 2.hours.ago)
    feeds(:failing).update!(last_fetched_at: nil)

    assert_enqueued_jobs 2, only: FeedRefreshJob do
      RefreshDueFeedsJob.perform_now
    end

    expected_ids = [ feeds(:stale).id, feeds(:failing).id ].sort
    enqueued_ids = enqueued_jobs.select { |j| j[:job] == FeedRefreshJob }.map { |j| j[:args].first }.sort
    assert_equal expected_ids, enqueued_ids
  end
end
