class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  # Supported third-party sign-in providers. `credential` is the prefix for the
  # `<prefix>_client_id` / `<prefix>_client_secret` credentials (read via
  # Rails.app.creds.option), keeping naming consistent across the initializer,
  # views, and this model. The key is the OmniAuth strategy name.
  PROVIDERS = {
    "github" => { label: "GitHub", credential: "github" },
    "google_oauth2" => { label: "Google", credential: "google" }
  }.freeze

  # Providers that actually have credentials set, in declaration order. Used to
  # decide which sign-in buttons to render and which OmniAuth strategies to load.
  def self.configured_providers
    PROVIDERS.select { |name, _| configured?(name) }
  end

  def self.configured?(provider)
    cfg = PROVIDERS[provider.to_s]
    cfg && Rails.app.creds.option(:"#{cfg[:credential]}_client_id", default: nil).present?
  end

  def self.label_for(provider)
    PROVIDERS.dig(provider.to_s, :label) || provider.to_s.titleize
  end

  def label
    self.class.label_for(provider)
  end
end
