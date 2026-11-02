class Subscriptions::BaseController < ApplicationController
  private
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
        format.turbo_stream { render template: "subscriptions/refresh" }
        format.html { redirect_to subscriptions_path, notice: notice, alert: alert }
      end
    end
end
