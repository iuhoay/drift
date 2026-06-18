# Keeps WebSub push subscriptions alive. WebSub leases expire (the hub stops pushing
# unless we re-subscribe), so this reconciler runs periodically to:
#   1. backfill — subscribe any YouTube feed that has no subscription yet (this is how
#      pre-existing feeds get onboarded after the feature ships), and
#   2. renew — re-subscribe any subscription whose lease is missing or near expiry.
# Both funnel through WebSubSubscribeJob, which is idempotent. Only scheduled in
# production (config/recurring.yml) — where the hub can reach our callback.
class RenewWebSubLeasesJob < ApplicationJob
  queue_as :default

  def perform
    Feed.youtube.where.missing(:web_sub_subscription).find_each do |feed|
      WebSubSubscribeJob.perform_later(feed.id)
    end

    WebSubSubscription.renewable.expiring(WebSubSubscription::RENEW_WITHIN.from_now).find_each do |subscription|
      WebSubSubscribeJob.perform_later(subscription.feed_id)
    end
  end
end
