class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [ :update, :destroy ]

  def index
    @subscriptions = Current.user.subscriptions.joins(:feed).includes(:feed).order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
  end

  def new
    @subscription = Current.user.subscriptions.new
  end

  def create
    input_url = params.dig(:subscription, :feed_url).to_s.strip
    @subscription = Current.user.subscriptions.new

    if input_url.blank?
      @subscription.errors.add(:feed_url, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    feed_url = resolve_feed_url(input_url)

    if feed_url.blank?
      @subscription.errors.add(:feed_url, "no feed found at that address")
      return render :new, status: :unprocessable_entity
    end

    feed = Feed.find_or_initialize_by(feed_url: feed_url)
    feed.title ||= feed_url

    Feed.transaction do
      feed.save!
      @subscription = Current.user.subscriptions.find_or_create_by!(feed: feed) do |s|
        s.custom_title = params.dig(:subscription, :custom_title).presence
      end
    end

    FeedRefreshJob.perform_later(feed.id)

    redirect_to subscriptions_path, notice: "Subscribed to #{feed.display_title}."
  rescue ActiveRecord::RecordInvalid => e
    @subscription.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  end

  def update
    if @subscription.update(subscription_params)
      redirect_to subscriptions_path, notice: "Subscription updated."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @subscription.destroy
    redirect_to subscriptions_path, notice: "Unsubscribed."
  end

  private

  def set_subscription
    @subscription = Current.user.subscriptions.find(params[:id])
  end

  # Turns the address the user pasted into an actual feed URL. A URL we already
  # track is a feed by definition, so we skip the network round-trip; anything
  # else is run through auto-detection.
  def resolve_feed_url(input_url)
    return input_url if Feed.exists?(feed_url: input_url)

    Feed::Discovery.call(input_url).first
  end

  def subscription_params
    params.expect(subscription: [ :custom_title ])
  end
end
