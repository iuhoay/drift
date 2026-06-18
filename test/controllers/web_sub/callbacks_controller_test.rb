require "test_helper"

class WebSub::CallbacksControllerTest < ActionDispatch::IntegrationTest
  PUSH_BODY = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
      <title>YouTube Channel</title>
      <link rel="alternate" href="https://www.youtube.com/channel/UCfixture0000000000001"/>
      <entry>
        <id>yt:video:VIDEO999</id>
        <yt:videoId>VIDEO999</yt:videoId>
        <title>Delivered Video</title>
        <link rel="alternate" href="https://www.youtube.com/watch?v=VIDEO999"/>
        <author><name>YouTube Channel</name></author>
        <published>2026-06-18T10:00:00+00:00</published>
        <updated>2026-06-18T10:05:00+00:00</updated>
      </entry>
    </feed>
  XML

  setup { @subscription = web_sub_subscriptions(:youtube) }

  test "GET verify echoes the challenge and activates when topic and token match" do
    get web_sub_callback_path(token: @subscription.callback_token), params: {
      "hub.mode" => "subscribe",
      "hub.topic" => @subscription.topic_url,
      "hub.challenge" => "challenge-123",
      "hub.lease_seconds" => "86400"
    }

    assert_response :success
    assert_equal "challenge-123", @response.body
    assert @subscription.reload.active?
    assert_in_delta 86_400, @subscription.lease_expires_at - Time.current, 5
  end

  test "GET verify 404s on a topic mismatch" do
    get web_sub_callback_path(token: @subscription.callback_token), params: {
      "hub.mode" => "subscribe",
      "hub.topic" => "https://www.youtube.com/feeds/videos.xml?channel_id=SOMEONE_ELSE",
      "hub.challenge" => "challenge-123"
    }

    assert_response :not_found
  end

  test "GET verify 404s on an unknown token" do
    get web_sub_callback_path(token: "does-not-exist"), params: {
      "hub.mode" => "subscribe", "hub.topic" => "x", "hub.challenge" => "y"
    }

    assert_response :not_found
  end

  test "POST receive ingests a validly-signed payload and returns 204" do
    assert_difference -> { @subscription.feed.entries.count }, 1 do
      post web_sub_callback_path(token: @subscription.callback_token),
           params: PUSH_BODY, headers: signed_headers(PUSH_BODY)
    end

    assert_response :no_content
    assert @subscription.feed.entries.exists?(title: "Delivered Video")
    assert_not_nil @subscription.reload.last_delivery_at
  end

  test "POST receive drops an unsigned payload with 404 and ingests nothing" do
    assert_no_difference -> { @subscription.feed.entries.count } do
      post web_sub_callback_path(token: @subscription.callback_token),
           params: PUSH_BODY, headers: { "CONTENT_TYPE" => "application/atom+xml" }
    end

    assert_response :not_found
  end

  test "POST receive drops a wrongly-signed payload with 404" do
    assert_no_difference -> { @subscription.feed.entries.count } do
      post web_sub_callback_path(token: @subscription.callback_token),
           params: PUSH_BODY,
           headers: { "CONTENT_TYPE" => "application/atom+xml", "X-Hub-Signature" => "sha1=deadbeef" }
    end

    assert_response :not_found
  end

  test "POST receive accepts a request with an empty (non-browser) User-Agent" do
    post web_sub_callback_path(token: @subscription.callback_token),
         params: PUSH_BODY, headers: signed_headers(PUSH_BODY).merge("HTTP_USER_AGENT" => "")

    assert_response :no_content
  end

  private

  def signed_headers(body)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, @subscription.secret, body)
    { "CONTENT_TYPE" => "application/atom+xml", "X-Hub-Signature" => "sha1=#{signature}" }
  end
end
