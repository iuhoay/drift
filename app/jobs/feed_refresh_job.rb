class FeedRefreshJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    Feed::Refresher.call(feed)
  end
end
