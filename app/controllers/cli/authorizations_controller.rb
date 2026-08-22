# Browser half of `drift auth login`. GET is a confirm page (side-effect free).
# POST mints a short-lived CliAuthorization and redirects to the CLI's loopback
# listener with a one-time code — never the ApiToken itself.
class Cli::AuthorizationsController < ApplicationController
  before_action :assign_oauth_params
  before_action :require_valid_oauth_request

  def new
  end

  def create
    authorization = Current.user.cli_authorizations.create!(expires_at: CliAuthorization::TTL.from_now)
    redirect_to authorization.callback_url(@redirect_uri, @state), allow_other_host: true
  rescue ArgumentError
    render :invalid, status: :unprocessable_entity
  end

  private
    def assign_oauth_params
      @redirect_uri = params[:redirect_uri].to_s
      @state = params[:state].to_s
    end

    def require_valid_oauth_request
      return if CliAuthorization.loopback_redirect?(@redirect_uri) && CliAuthorization.valid_state?(@state)

      render :invalid, status: :unprocessable_entity
    end
end
