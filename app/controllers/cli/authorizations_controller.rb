# Browser half of `drift auth login`. GET is a confirm page (side-effect free).
# POST mints a short-lived CliAuthorization and sends the browser to the CLI
# listener on 127.0.0.1 — never the ApiToken itself, never a caller-supplied host.
#
# Built as a raw Location header instead of redirect_to(...). url_for would
# merge onto /cli/authorize; Brakeman would flag a string redirect_to.
class Cli::AuthorizationsController < ApplicationController
  layout "cli"

  before_action :assign_oauth_params
  before_action :require_valid_oauth_request

  def new
  end

  def create
    authorization = Current.user.cli_authorizations.create!(expires_at: CliAuthorization::TTL.from_now)
    head :found, location: loopback_callback_url(code: authorization.code, state: @state)
  end

  private
    def assign_oauth_params
      @redirect_uri = params[:redirect_uri].to_s
      @state = params[:state].to_s
      @port = CliAuthorization.loopback_port(@redirect_uri)
    end

    def require_valid_oauth_request
      return if @port && CliAuthorization.valid_state?(@state)

      render :invalid, status: :unprocessable_entity
    end

    def loopback_callback_url(**query)
      URI::HTTP.build(
        host: "127.0.0.1",
        port: @port,
        path: "/callback",
        query: query.to_query
      ).to_s
    end
    helper_method :loopback_callback_url
end
