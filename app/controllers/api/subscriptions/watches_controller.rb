class Api::Subscriptions::WatchesController < Api::BaseController
  before_action :set_subscription

  def create
    @subscription.watch
    render "api/subscriptions/update"
  end

  def destroy
    @subscription.unwatch
    render "api/subscriptions/update"
  end

  private
    def set_subscription
      @subscription = current_user.subscriptions.includes(:feed).find(params[:subscription_id])
    end
end
