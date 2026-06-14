# Third-party sign-in. Each provider is only registered when its credentials
# are present, so the app boots and runs fine with no OAuth keys configured —
# the sign-in buttons simply don't render (see Identity.configured_providers).
#
# Credentials are read with the project's Rails.app.creds helper, which merges
# .env in development and credentials in production. Keys:
#   github_client_id / github_client_secret
#   google_client_id / google_client_secret
Rails.application.config.middleware.use OmniAuth::Builder do
  github_id     = Rails.app.creds.option(:github_client_id, default: nil)
  github_secret = Rails.app.creds.option(:github_client_secret, default: nil)
  if github_id.present? && github_secret.present?
    provider :github, github_id, github_secret, scope: "user:email"
  end

  google_id     = Rails.app.creds.option(:google_client_id, default: nil)
  google_secret = Rails.app.creds.option(:google_client_secret, default: nil)
  if google_id.present? && google_secret.present?
    provider :google_oauth2, google_id, google_secret
  end
end

OmniAuth.config.logger = Rails.logger

# Always route failures (including the CSRF check from
# omniauth-rails_csrf_protection) to Sessions::OmniauthController#failure via the
# /auth/failure endpoint, in every environment.
OmniAuth.config.failure_raise_out_environments = []
