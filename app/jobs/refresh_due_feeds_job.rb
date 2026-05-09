class RefreshDueFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.due_for_refresh.find_each do |feed|
      FeedRefreshJob.perform_later(feed.id)
    end
  end
end
