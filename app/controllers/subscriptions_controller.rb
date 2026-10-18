class SubscriptionsController < Subscriptions::BaseController
  before_action :set_subscription, only: [ :update, :destroy ]

  def index
    load_index
  end

  def new
    @subscription = Current.user.subscriptions.new
    load_category_options
  end

  def create
    @subscription = Subscription.subscribe(
      Current.user,
      params.dig(:subscription, :feed_url),
      custom_title: params.dig(:subscription, :custom_title),
      category: params.dig(:subscription, :category)
    )

    if @subscription.persisted?
      redirect_to subscriptions_path, notice: "Subscribed to #{@subscription.feed.display_title}."
    else
      load_category_options
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @subscription.update(subscription_params)
      refresh_index
    else
      refresh_index(alert: @subscription.errors.full_messages.to_sentence)
    end
  end

  def destroy
    @subscription.destroy
    refresh_index(notice: "Unsubscribed.")
  end

  private
    def set_subscription
      @subscription = Current.user.subscriptions.find(params[:id])
    end

    def subscription_params
      params.expect(subscription: [ :custom_title, :category ])
    end
end
