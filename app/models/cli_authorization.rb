# A one-time code minted when the user authorizes `drift auth login` in the
# browser. The CLI redeems it at POST /api/cli/token for a long-lived ApiToken.
# The grant itself is not a credential: it expires in TTL and can be used once.
#
# redirect_uri is never stored. Only its port is used; the authorize action
# always sends the browser to http://127.0.0.1:<port>/callback.
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
  CALLBACK_PATHS = [ "", "/", "/callback" ].freeze

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

  # The CLI binds 127.0.0.1. Anything else is rejected; we only take the port.
  def self.loopback_port(value)
    uri = URI.parse(value.to_s)
    return unless uri.is_a?(URI::HTTP) && uri.scheme == "http"
    return if uri.userinfo.present?
    return unless uri.host == "127.0.0.1"
    return unless CALLBACK_PATHS.include?(uri.path)

    uri.port
  rescue URI::InvalidURIError
    nil
  end

  def self.valid_state?(value)
    value.to_s.match?(STATE)
  end
end
