class Api::SubscriptionsController < Api::BaseController
  def index
    subscriptions = current_user.subscriptions.joins(:feed).includes(:feed)
      .order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))

    render json: { subscriptions: subscriptions.map { |subscription| serialize(subscription) } }
  end

  private

  def serialize(subscription)
    {
      id: subscription.id,
      feed_id: subscription.feed_id,
      title: subscription.display_title,
      feed_url: subscription.feed.feed_url
    }
  end
end
