require "test_helper"

class WebSubSubscriptionTest < ActiveSupport::TestCase
  test "subscribe! posts the expected parameters to the hub and persists" do
    feed = feeds(:youtube_pending)
    subscription = feed.build_web_sub_subscription
    connection, captured = stub_hub(202)

    subscription.subscribe!(http: connection)
    params = Rack::Utils.parse_query(captured[:body])

    assert_equal "subscribe", params["hub.mode"]
    assert_equal feed.feed_url, params["hub.topic"]
    assert_equal subscription.callback_url, params["hub.callback"]
    assert_equal "async", params["hub.verify"]
    assert_equal subscription.secret, params["hub.secret"]
    assert_equal WebSubSubscription::LEASE_SECONDS.to_s, params["hub.lease_seconds"]
    assert subscription.persisted?
  end

  test "subscribe! raises when the hub rejects the request" do
    subscription = feeds(:youtube_pending).build_web_sub_subscription
    connection, = stub_hub(400)

    assert_raises(WebSubSubscription::Error) { subscription.subscribe!(http: connection) }
  end

  test "valid_signature? accepts a correct sha1 HMAC and rejects everything else" do
    subscription = web_sub_subscriptions(:youtube)
    body = "<feed><entry/></feed>"
    good = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, subscription.secret, body)

    assert subscription.valid_signature?(body, "sha1=#{good}")
    assert_not subscription.valid_signature?(body, "sha1=#{good}ff"), "tampered signature"
    assert_not subscription.valid_signature?(body, "sha256=#{good}"), "wrong algorithm"
    assert_not subscription.valid_signature?(body, nil), "missing header"
    assert_not subscription.valid_signature?("tampered body", "sha1=#{good}")
  end

  test "active? requires the active state and an unexpired lease" do
    subscription = web_sub_subscriptions(:youtube)
    assert subscription.active?

    subscription.update!(lease_expires_at: 1.hour.ago)
    assert_not subscription.active?, "expired lease"

    subscription.update!(lease_expires_at: 1.day.from_now, state: "pending")
    assert_not subscription.active?, "not yet confirmed"
  end

  test "confirm_subscription! activates and stores the granted lease" do
    subscription = feeds(:youtube_pending).create_web_sub_subscription!

    subscription.confirm_subscription!("86400")

    assert subscription.active?
    assert_in_delta 86_400, subscription.lease_expires_at - Time.current, 5
    assert_not_nil subscription.verified_at
  end

  test "renewable.expiring finds near-expiry subscriptions, not healthy ones" do
    healthy = web_sub_subscriptions(:youtube) # lease 5 days out
    window = WebSubSubscription::RENEW_WITHIN.from_now

    assert_not_includes WebSubSubscription.renewable.expiring(window), healthy

    healthy.update!(lease_expires_at: 1.hour.from_now)
    assert_includes WebSubSubscription.renewable.expiring(window), healthy
  end

  test "credentials are generated on create" do
    subscription = feeds(:youtube_pending).create_web_sub_subscription!

    assert subscription.callback_token.present?
    assert subscription.secret.present?
  end

  private

  # A Faraday test connection that captures the posted body, mirroring the
  # stub_http helper in Feed::RefresherTest.
  def stub_hub(status)
    captured = {}
    connection = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.post(WebSubSubscription::HUB_URL) do |env|
          captured[:body] = env.body
          [ status, {}, "" ]
        end
      end
    end
    [ connection, captured ]
  end
end
