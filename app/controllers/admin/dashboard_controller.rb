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

      @active_users = Session.where(last_active_at: 7.days.ago..).distinct.count(:user_id)
      @entries_last_24h = Entry.where(created_at: 24.hours.ago..).count
      @feed_kinds = feed_kind_breakdown

      @failing_feeds = Feed.failing.count
      @dead_feeds = Feed.dead.count
      @last_success_at = Feed.maximum(:last_success_at)

      @problem_feeds = Feed.troubled.limit(15).to_a
      @recent = recent_activity
    end

    private
      def require_admin
        redirect_to root_path, alert: "Access denied" unless Current.user&.admin?
      end

      # Partitions every feed into the three buckets that drive its cadence:
      # YouTube (longer interval), Bilibili (synthesized), and plain RSS.
      def feed_kind_breakdown
        youtube  = Feed.youtube.count
        bilibili = Feed.where(kind: "bilibili").count
        { youtube: youtube, bilibili: bilibili, rss: @stats[:feeds] - youtube - bilibili }
      end

      # Newest events across the instance for the activity pulse — feeds added,
      # users joined, and feeds last fetched — merged newest-first. Read-only
      # view prep, so it lives here rather than spawning a service object.
      def recent_activity
        feeds_added  = Feed.order(created_at: :desc).limit(5).map { |f| { type: :feed_added, at: f.created_at, feed: f } }
        users_joined = User.order(created_at: :desc).limit(5).map { |u| { type: :user_joined, at: u.created_at, user: u } }
        fetched      = Feed.where.not(last_success_at: nil).order(last_success_at: :desc).limit(5).map { |f| { type: :fetched, at: f.last_success_at, feed: f } }

        (feeds_added + users_joined + fetched).sort_by { |event| event[:at] }.reverse.first(8)
      end
  end
end
