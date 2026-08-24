class WatchNotifyJob < ApplicationJob
  queue_as :default

  def perform(feed_id, entry_ids)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    feed.notify_watchers_now(entry_ids)
  end
end
