# Browser half of `drift auth login`. GET is a confirm page (side-effect free).
# POST mints a short-lived CliAuthorization and redirects to the CLI listener
# on 127.0.0.1 — never the ApiToken itself, never a caller-supplied host.
class Cli::AuthorizationsController < ApplicationController
  before_action :assign_oauth_params
  before_action :require_valid_oauth_request

  def new
  end

  def create
    authorization = Current.user.cli_authorizations.create!(expires_at: CliAuthorization::TTL.from_now)
    redirect_to({ protocol: "http", host: "127.0.0.1", port: @port,
                  path: "/callback",
                  params: { code: authorization.code, state: @state } },
                allow_other_host: true)
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
end
