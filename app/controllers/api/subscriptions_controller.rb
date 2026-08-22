class Api::SubscriptionsController < Api::BaseController
  def index
    @subscriptions = current_user.subscriptions.joins(:feed).includes(:feed)
      .order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
  end
end
