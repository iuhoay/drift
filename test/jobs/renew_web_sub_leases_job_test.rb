require "test_helper"

class RenewWebSubLeasesJobTest < ActiveJob::TestCase
  test "enqueues a subscribe for youtube feeds that have no subscription" do
    RenewWebSubLeasesJob.perform_now

    assert_includes subscribed_feed_ids, feeds(:youtube_pending).id
  end

  test "re-subscribes a subscription whose lease is near expiry" do
    web_sub_subscriptions(:youtube).update!(lease_expires_at: 1.hour.from_now)

    RenewWebSubLeasesJob.perform_now

    assert_includes subscribed_feed_ids, feeds(:youtube).id
  end

  test "leaves a healthy, far-from-expiry subscription alone" do
    RenewWebSubLeasesJob.perform_now

    # :youtube already has a subscription (so not backfilled) with a 5-day lease
    # (so not renewed).
    assert_not_includes subscribed_feed_ids, feeds(:youtube).id
  end

  private

  def subscribed_feed_ids
    enqueued_jobs.select { |job| job[:job] == WebSubSubscribeJob }.map { |job| job[:args].first }
  end
end
