class Api::SubscriptionsController < Api::BaseController
  def index
    @subscriptions = current_user.subscriptions.joins(:feed).includes(:feed)
      .order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
  end

  def update
    @subscription = current_user.subscriptions.includes(:feed).find(params[:id])

    if @subscription.update(subscription_params)
      render :update
    else
      render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def subscription_params
    params.expect(subscription: [ :category ])
  end
end
