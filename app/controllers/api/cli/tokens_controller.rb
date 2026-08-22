# Token endpoint for the CLI loopback login. The one-time code is the secret, so
# this inherits ActionController::Base (no cookie session, no bearer token).
class Api::Cli::TokensController < ActionController::Base
  skip_forgery_protection
  rate_limit to: 20, within: 1.minute

  def create
    authorization = CliAuthorization.find_by(code: params[:code].to_s)
    token = authorization&.redeem!

    if token
      render json: { token: token.token }, status: :created
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  rescue CliAuthorization::RedeemError
    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
