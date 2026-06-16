# Base for the JSON API the browser extension talks to. Deliberately inherits
# straight from ActionController::Base rather than ApplicationController: no
# cookie session, no CSRF token (there's no browser form), and no modern-browser
# gate. Authentication is a bearer ApiToken instead.
class Api::BaseController < ActionController::Base
  skip_forgery_protection

  before_action :authenticate_token

  private

  def authenticate_token
    token = request.headers["Authorization"].to_s.sub(/\ABearer\s+/i, "")
    @api_token = ApiToken.find_by(token: token) if token.present?

    if @api_token
      @api_token.touch_last_used!
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end

  def current_user
    @api_token.user
  end
end
