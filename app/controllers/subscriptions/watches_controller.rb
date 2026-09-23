class Subscriptions::WatchesController < ApplicationController
  before_action :set_subscription

  def create
    @subscription.watch
    respond_watch
  end

  def destroy
    @subscription.unwatch
    respond_watch
  end

  private
    def set_subscription
      @subscription = Current.user.subscriptions.find(params[:subscription_id])
    end

    def respond_watch
      respond_to do |format|
        format.turbo_stream { render :toggle }
        format.html { redirect_back fallback_location: subscriptions_path }
      end
    end
end
