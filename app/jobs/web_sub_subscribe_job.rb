# (Re)subscribes a single feed to its WebSub hub. Idempotent: reuses the feed's
# existing subscription (and its token/secret) if one exists, otherwise builds one.
class WebSubSubscribeJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    subscription = feed.web_sub_subscription || feed.build_web_sub_subscription
    subscription.subscribe!
  end
end
