require "test_helper"

class CliAuthorizationTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "generates a code on create" do
    grant = @user.cli_authorizations.create!(expires_at: 5.minutes.from_now)
    assert grant.code.present?
  end

  test "redeem! mints an API token and can only run once" do
    grant = @user.cli_authorizations.create!(expires_at: 5.minutes.from_now)

    assert_difference -> { @user.api_tokens.count } => 1 do
      token = grant.redeem!
      assert_equal "CLI", token.name
      assert token.token.present?
    end

    assert grant.reload.consumed?
    assert_raises(CliAuthorization::RedeemError) { grant.redeem! }
  end

  test "redeem! rejects an expired grant" do
    grant = @user.cli_authorizations.create!(expires_at: 1.minute.ago)

    assert_no_difference -> { @user.api_tokens.count } do
      assert_raises(CliAuthorization::RedeemError) { grant.redeem! }
    end
  end

  test "loopback_redirect? allows only http loopback hosts" do
    assert CliAuthorization.loopback_redirect?("http://127.0.0.1:12345/callback")
    assert CliAuthorization.loopback_redirect?("http://localhost:9/callback")
    assert CliAuthorization.loopback_redirect?("http://[::1]:12345/callback")

    assert_not CliAuthorization.loopback_redirect?("https://127.0.0.1:12345/callback")
    assert_not CliAuthorization.loopback_redirect?("http://127.0.0.1.evil.test/callback")
    assert_not CliAuthorization.loopback_redirect?("http://example.com/callback")
    assert_not CliAuthorization.loopback_redirect?("http://user@127.0.0.1/callback")
    assert_not CliAuthorization.loopback_redirect?("not-a-url")
  end

  test "valid_state? requires a short opaque token" do
    assert CliAuthorization.valid_state?("abcdefgh")
    assert CliAuthorization.valid_state?("a" * 128)
    assert_not CliAuthorization.valid_state?("short")
    assert_not CliAuthorization.valid_state?("bad state")
    assert_not CliAuthorization.valid_state?("a" * 129)
  end
end
