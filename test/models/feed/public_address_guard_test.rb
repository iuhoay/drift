require "test_helper"

class Feed::PublicAddressGuardTest < ActiveSupport::TestCase
  test "blocks loopback addresses" do
    assert_blocked "http://127.0.0.1/feed.xml"
  end

  test "blocks the cloud metadata (link-local) address" do
    assert_blocked "http://169.254.169.254/latest/meta-data/"
  end

  test "blocks private addresses" do
    assert_blocked "http://10.0.0.5/feed.xml"
    assert_blocked "http://192.168.1.1/feed.xml"
  end

  test "lets public addresses through to the adapter" do
    response = connection.get("http://93.184.216.34/feed.xml")

    assert_equal 200, response.status
    assert_equal "ok", response.body
  end

  private

  # A guarded connection whose adapter is stubbed, so a request that clears the
  # guard never touches the network and a blocked one raises before it would.
  def connection
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("http://93.184.216.34/feed.xml") { [ 200, {}, "ok" ] }

    Faraday.new do |f|
      f.use Feed::PublicAddressGuard
      f.adapter :test, stubs
    end
  end

  def assert_blocked(url)
    assert_raises(Feed::PublicAddressGuard::BlockedAddress) { connection.get(url) }
  end
end
