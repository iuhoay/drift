module Admin
  # Base controller for admin-only mounted engines (e.g. Mission Control Jobs).
  # Resolves the signed session cookie directly and redirects via main_app, because
  # those engines isolate their namespace — bare app route helpers aren't available here.
  class BaseController < ActionController::Base
    before_action :require_admin

    private
      def require_admin
        user = Session.find_by(id: cookies.signed[:session_id])&.user
        redirect_to main_app.root_path, alert: "Access denied" unless user&.admin?
      end
  end
end
