require "openssl"

# A WebSub (PubSubHubbub) push subscription for a single feed. Instead of polling
# the feed's URL, we register a callback with the feed's hub once; the hub then
# POSTs us the feed (as Atom) whenever it changes. Used for YouTube channel feeds,
# whose `feeds/videos.xml` endpoint throttles polling at scale — see Feed#youtube?.
#
# The stored feed_url *is* the WebSub topic (YouTube advertises the Google hub on
# that URL), so there's no separate topic column.
class WebSubSubscription < ApplicationRecord
  # Google's public hub — it operates the WebSub hub for every youtube.com feed.
  HUB_URL = "https://pubsubhubbub.appspot.com/subscribe"

  # Lease we *request*; the hub dictates the actual lease in its verification GET,
  # which we store in lease_expires_at. RenewWebSubLeasesJob re-subscribes before it.
  LEASE_SECONDS = 10.days.to_i

  # How close to expiry we re-subscribe (the renew job's window).
  RENEW_WITHIN = 2.days

  STATES = %w[pending active denied expired].freeze

  # Raised when the hub rejects a subscribe/unsubscribe request.
  class Error < StandardError; end

  belongs_to :feed

  before_validation :ensure_credentials, on: :create

  validates :callback_token, presence: true, uniqueness: true
  validates :secret, presence: true
  validates :state, inclusion: { in: STATES }

  scope :active, -> { where(state: "active") }
  # Subscriptions worth (re)subscribing: confirmed or still-pending ones whose lease
  # is missing or near/!past expiry. Denied/expired ones are left alone.
  scope :renewable, -> { where(state: %w[pending active]) }
  scope :expiring, ->(before) {
    where("lease_expires_at IS NULL OR lease_expires_at <= ?", before)
  }

  # Push is only useful where the hub can actually reach our callback, i.e. a
  # publicly routable host — production. Dev/test have no reachable callback, so we
  # don't fire real subscriptions there (the model methods still run when called
  # directly, so they remain unit-testable). Mirrors Feed::Bilibili.enabled?.
  def self.enabled?
    Rails.env.production?
  end

  # The feed's URL doubles as the WebSub topic.
  def topic_url
    feed.feed_url
  end

  def callback_url
    Rails.application.routes.url_helpers.web_sub_callback_url(token: callback_token)
  end

  def active?
    state == "active" && lease_expires_at&.future?
  end

  # Whether an operator should look at this subscription: the hub denied us, the
  # lease expired, or a once-confirmed ("active") subscription's lease has lapsed
  # without renewal — in which case the hub has very likely stopped delivering and
  # only polling keeps the feed fresh. Drives the admin WebSub dashboard's triage.
  def needs_attention?
    state.in?(%w[denied expired]) || (state == "active" && !active?)
  end

  # Ask the hub to (re)subscribe. The hub confirms asynchronously by calling our
  # verify endpoint, which flips state to "active" — so this only fires the request.
  # http is injectable for tests, mirroring Feed::Refresher.
  def subscribe!(http: Feed.http_connection)
    save! if new_record?
    request_hub("subscribe", http)
    self
  end

  def unsubscribe!(http: Feed.http_connection)
    return self if new_record?

    request_hub("unsubscribe", http)
    self
  end

  # Called from the verify callback once the hub confirms a subscribe. The hub
  # supplies the granted lease in seconds; we store the absolute expiry.
  def confirm_subscription!(lease_seconds)
    seconds = lease_seconds.to_i
    update!(
      state: "active",
      verified_at: Time.current,
      lease_expires_at: seconds.positive? ? Time.current + seconds : nil
    )
  end

  def confirm_unsubscription!
    update!(state: "expired", verified_at: Time.current)
  end

  def record_delivery!
    update_column(:last_delivery_at, Time.current)
  end

  # Verifies a content-distribution POST really came from the hub. Google's hub
  # signs the raw body with HMAC-SHA1 keyed by the secret we sent at subscribe time,
  # sending it as `X-Hub-Signature: sha1=<hex>`. Constant-time compared.
  def valid_signature?(raw_body, header)
    return false if secret.blank? || header.blank?

    algorithm, signature = header.to_s.split("=", 2)
    return false unless algorithm == "sha1" && signature.present?

    expected = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, secret, raw_body.to_s)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  private

  def ensure_credentials
    self.callback_token ||= SecureRandom.urlsafe_base64(24)
    self.secret ||= SecureRandom.hex(20)
  end

  def request_hub(mode, http)
    response = http.post(HUB_URL) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(hub_params(mode))
    end
    return response if response.success?

    raise Error, "WebSub #{mode} for feed #{feed_id} failed: HTTP #{response.status}"
  end

  def hub_params(mode)
    params = {
      "hub.mode" => mode,
      "hub.topic" => topic_url,
      "hub.callback" => callback_url,
      "hub.verify" => "async"
    }
    if mode == "subscribe"
      params["hub.secret"] = secret
      params["hub.lease_seconds"] = LEASE_SECONDS.to_s
    end
    params
  end
end
