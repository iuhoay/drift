require "active_support/core_ext/integer/time"

Rails.application.configure do
  app_host = ENV["APP_HOST"]

  if app_host.blank?
    raise KeyError, 'key not found: "APP_HOST"' unless ENV["SECRET_KEY_BASE_DUMMY"]

    app_host = "example.com"
  end

  app_protocol = ENV.fetch("APP_PROTOCOL", "https")
  app_url_options = { host: app_host, protocol: app_protocol }
  app_hosts = ENV.fetch("APP_HOSTS", app_host).split(",").map(&:strip)
  force_ssl = ENV.fetch("FORCE_SSL", "true") != "false"

  # Outgoing mail. SMTP_* and MAILER_FROM_ADDRESS are supplied by the host's
  # settings UI at runtime (see ONCE deployment docs). Until SMTP_ADDRESS is
  # set, delivery stays off so a fresh deploy boots without a mail server and
  # queued reset emails don't pile up as failing jobs.
  smtp_address = ENV["SMTP_ADDRESS"]

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = force_ssl

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = force_ssl

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default file-based cache store with a more robust alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by absolute links, including password reset emails.
  config.action_mailer.default_url_options = app_url_options
  config.action_controller.default_url_options = app_url_options
  Rails.application.routes.default_url_options = app_url_options

  # Outgoing SMTP, driven entirely by ENV (set via the host's settings UI).
  if smtp_address.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address:              smtp_address,
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:            ENV["SMTP_USERNAME"].presence,
      password:             ENV["SMTP_PASSWORD"].presence,
      authentication:       ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: true
    }
  else
    # No SMTP configured yet — accept but drop mail rather than erroring.
    config.action_mailer.perform_deliveries = false
    config.action_mailer.raise_delivery_errors = false
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts.concat(app_hosts)
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
