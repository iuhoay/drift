class ApplicationMailer < ActionMailer::Base
  # In production MAILER_FROM_ADDRESS is supplied by the host's settings UI
  # (see config/environments/production.rb); dev/test fall back to a placeholder.
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "no-reply@example.com")
  layout "mailer"
end
