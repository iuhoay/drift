module Admin
  # Read-only operational view of WebSub (PubSubHubbub) push subscriptions — the
  # YouTube-feed push pipeline (see WebSubSubscription). Mirrors
  # Admin::DashboardController: a regular ApplicationController action behind the
  # admin gate, so it gets the application layout, authentication, and Current.
  class WebSubSubscriptionsController < ApplicationController
    before_action :require_admin

    def index
      subscriptions = WebSubSubscription.includes(:feed)
                                        .order(Arel.sql("lease_expires_at ASC NULLS LAST"))
                                        .to_a

      @counts = WebSubSubscription::STATES.index_with(0).merge(WebSubSubscription.group(:state).count)
      @total  = subscriptions.size

      @problems = subscriptions.select(&:needs_attention?)
      @healthy  = subscriptions - @problems

      @renew_within     = WebSubSubscription::RENEW_WITHIN
      renew_cutoff      = @renew_within.from_now
      @expiring_soon    = @healthy.count { |s| s.active? && s.lease_expires_at <= renew_cutoff }
      @awaiting_first   = subscriptions.count { |s| s.last_delivery_at.nil? }
      @last_delivery_at = subscriptions.filter_map(&:last_delivery_at).max
    end

    private
      def require_admin
        redirect_to root_path, alert: "Access denied" unless Current.user&.admin?
      end
  end
end
