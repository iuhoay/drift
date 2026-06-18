class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [ :update, :destroy ]

  def index
    @subscriptions = Current.user.subscriptions.joins(:feed).includes(:feed).order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
  end

  def new
    @subscription = Current.user.subscriptions.new
  end

  def create
    @subscription = Subscription.subscribe(
      Current.user,
      params.dig(:subscription, :feed_url),
      custom_title: params.dig(:subscription, :custom_title)
    )

    if @subscription.persisted?
      redirect_to subscriptions_path, notice: "Subscribed to #{@subscription.feed.display_title}."
    else
      render :new, status: :unprocessable_entity
    end
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
