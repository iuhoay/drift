class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [ :update, :destroy ]

  def index
    @subscriptions = Current.user.subscriptions.joins(:feed).includes(:feed).order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
  end

  def new
    @subscription = Current.user.subscriptions.new
  end

  def create
    feed_url = params.dig(:subscription, :feed_url).to_s.strip
    @subscription = Current.user.subscriptions.new

    if feed_url.blank?
      @subscription.errors.add(:feed_url, "can't be blank")
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

  def subscription_params
    params.expect(subscription: [ :custom_title ])
  end
end
