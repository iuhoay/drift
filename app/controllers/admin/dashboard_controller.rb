module Admin
  # First-party admin landing page. Unlike Admin::BaseController (which gates the
  # mounted engines and runs outside the app's normal request stack), this is a
  # regular ApplicationController action, so it gets full authentication, Current,
  # and the application layout. The admin gate runs after require_authentication.
  class DashboardController < ApplicationController
    before_action :require_admin

    def show
      @stats = {
        users: User.count,
        feeds: Feed.count,
        subscriptions: Subscription.count,
        entries: Entry.count
      }
      @failing_feeds = Feed.where("fetch_failure_count > 0").count
      @last_success_at = Feed.maximum(:last_success_at)
    end

    private
      def require_admin
        redirect_to root_path, alert: "Access denied" unless Current.user&.admin?
      end
  end
end
