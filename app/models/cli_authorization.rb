# A one-time code minted when the user authorizes `drift auth login` in the
# browser. The CLI redeems it at POST /api/cli/token for a long-lived ApiToken.
# The grant itself is not a credential: it expires in TTL and can be used once.
#
# redirect_uri is never stored — it is validated on the authorize request and
# only used to bounce the code back to the loopback listener.
# == Schema Information
#
# Table name: cli_authorizations
#
#  id          :bigint           not null, primary key
#  code        :string           not null
#  consumed_at :datetime
#  expires_at  :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_cli_authorizations_on_code     (code) UNIQUE
#  index_cli_authorizations_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class CliAuthorization < ApplicationRecord
  TTL = 5.minutes
  STATE = /\A[A-Za-z0-9_-]{8,128}\z/
  LOOPBACK_HOSTS = %w[127.0.0.1 localhost ::1 [::1]].freeze

  belongs_to :user

  has_secure_token :code

  validates :expires_at, presence: true

  class RedeemError < StandardError; end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def redeem!
    transaction do
      lock!
      raise RedeemError if expired? || consumed?

      user.api_tokens.create!(name: "CLI").tap do
        update!(consumed_at: Time.current)
      end
    end
  end

  def callback_url(redirect_uri, state)
    self.class.loopback_url(redirect_uri, [ [ "code", code ], [ "state", state ] ])
  end

  def self.denied_url(redirect_uri, state)
    loopback_url(redirect_uri, [ [ "error", "access_denied" ], [ "state", state ] ])
  end

  # Rebuilds an http URL from a whitelist host so the authorize redirect never
  # echoes the raw redirect_uri param (Brakeman Redirect).
  def self.loopback_url(redirect_uri, query_pairs)
    uri, host = parse_loopback(redirect_uri)
    raise ArgumentError, "not a loopback redirect" unless uri

    query = URI.decode_www_form(uri.query.to_s) + query_pairs
    URI::HTTP.build(
      host: host.delete_prefix("[").delete_suffix("]"),
      port: uri.port,
      path: uri.path.presence || "/",
      query: URI.encode_www_form(query)
    ).to_s
  end

  def self.loopback_redirect?(value)
    parse_loopback(value).present?
  end

  def self.parse_loopback(value)
    uri = URI.parse(value.to_s)
    return unless uri.is_a?(URI::HTTP) && uri.scheme == "http"
    return if uri.userinfo.present?

    host = LOOPBACK_HOSTS.find { |allowed| allowed == uri.host }
    return unless host

    [ uri, host ]
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :parse_loopback

  def self.valid_state?(value)
    value.to_s.match?(STATE)
  end
end
