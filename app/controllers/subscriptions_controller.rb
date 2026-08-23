class SubscriptionsController < ApplicationController
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

  def load_index
    @subscriptions = Current.user.subscriptions.joins(:feed).includes(:feed).order(Arel.sql("LOWER(COALESCE(NULLIF(subscriptions.custom_title, ''), feeds.title, feeds.feed_url))"))
    @category_options = category_names_from(@subscriptions)
  end

  def load_category_options
    @category_options = category_names_from(Current.user.subscriptions)
  end

  def category_names_from(subscriptions)
    subscriptions.filter_map(&:category).uniq.sort_by(&:downcase)
  end

  # Turbo Drive ignores a 200 HTML response to a form submit, so in-place
  # edits answer with a stream that swaps the list + sidebar. HTML clients
  # still get a redirect. See gotcha_form_create_render_breaks_turbo.
  def refresh_index(notice: nil, alert: nil)
    load_index
    flash.now[:notice] = notice if notice
    flash.now[:alert] = alert if alert

    respond_to do |format|
      format.turbo_stream { render :refresh }
      format.html { redirect_to subscriptions_path, notice: notice, alert: alert }
    end
  end
end
