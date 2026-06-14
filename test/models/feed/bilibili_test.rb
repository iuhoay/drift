require "test_helper"

class Feed::BilibiliTest < ActiveSupport::TestCase
  SPACE_URL = "https://space.bilibili.com/26846937".freeze

  NAV = {
    code: 0,
    data: {
      wbi_img: {
        img_url: "https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png",
        sub_url: "https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png"
      }
    }
  }.to_json

  SPI = { code: 0, data: { b_3: "BUVID3VALUE", b_4: "BUVID4VALUE" } }.to_json

  SEARCH = {
    code: 0,
    data: {
      list: {
        vlist: [
          {
            bvid: "BV1GJ411x7h7",
            title: "First video",
            description: "a <clip> & notes",
            author: "Tester",
            created: 1_700_000_000,
            pic: "//i0.hdslb.com/cover.jpg"
          }
        ]
      }
    }
  }.to_json

  test "recognizes a space URL and ignores its tracking query" do
    assert Feed::Bilibili.handles?("https://space.bilibili.com/26846937?spm_id_from=333.788")
    assert_equal "26846937", Feed::Bilibili.uid_from("https://space.bilibili.com/26846937?spm_id_from=x")
    assert_nil Feed::Bilibili.uid_from("https://example.com/feed.xml")
    assert_not Feed::Bilibili.handles?("https://example.com/feed.xml")
  end

  test "the integration is enabled outside production" do
    assert Feed::Bilibili.enabled?
  end

  test "discovery short-circuits a space URL to its canonical form without any HTTP" do
    assert_equal [ "https://space.bilibili.com/26846937" ],
                 Feed::Discovery.new("https://space.bilibili.com/26846937?spm_id_from=x").call
  end

  test "discovery does not recognize a space URL when the integration is disabled" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://space.bilibili.com/26846937") { [ 404, {}, "" ] }
    http = Faraday.new { |b| b.adapter :test, stubs }

    discovery = Feed::Discovery.new("https://space.bilibili.com/26846937", http: http, bilibili_enabled: false)
    assert_empty discovery.call
  end

  test "a Feed at a space URL is classified as the bilibili kind" do
    feed = Feed.new(feed_url: SPACE_URL)
    feed.valid?
    assert feed.bilibili?
  end

  test "fetch maps uploaded videos into feed-shaped, signed entries" do
    parsed = Feed::Bilibili.fetch(Feed.new(feed_url: SPACE_URL), stubbed_http)

    assert_equal "Tester · 哔哩哔哩", parsed.title
    assert_equal SPACE_URL, parsed.url

    entry = parsed.entries.sole
    assert_equal "BV1GJ411x7h7", entry.entry_id
    assert_equal "https://www.bilibili.com/video/BV1GJ411x7h7", entry.url
    assert_equal Time.at(1_700_000_000), entry.published
    assert_equal "a &lt;clip&gt; &amp; notes", entry.content.scan(/<p>(.*)<\/p>/).flatten.first # escaped, not raw HTML
  end

  test "nav reporting -101 (anonymous) still yields its public WBI keys and entries" do
    anon_nav = {
      code: -101, message: "账号未登录",
      data: { wbi_img: JSON.parse(NAV)["data"]["wbi_img"] }
    }.to_json

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://api.bilibili.com/x/frontend/finger/spi") { [ 200, json, SPI ] }
    stubs.get("https://api.bilibili.com/x/web-interface/nav") { [ 200, json, anon_nav ] }
    stubs.get("https://api.bilibili.com/x/space/wbi/arc/search") { [ 200, json, SEARCH ] }

    parsed = Feed::Bilibili.fetch(Feed.new(feed_url: SPACE_URL), http(stubs))
    assert_equal "BV1GJ411x7h7", parsed.entries.sole.entry_id
  end

  test "an API risk-control code surfaces as a Feed::Bilibili::Error" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://api.bilibili.com/x/frontend/finger/spi") { [ 200, json, SPI ] }
    stubs.get("https://api.bilibili.com/x/web-interface/nav") { [ 200, json, NAV ] }
    stubs.get("https://api.bilibili.com/x/space/wbi/arc/search") do
      [ 200, json, { code: -352, message: "risk control" }.to_json ]
    end

    error = assert_raises(Feed::Bilibili::Error) do
      Feed::Bilibili.fetch(Feed.new(feed_url: SPACE_URL), http(stubs))
    end
    assert_match(/-352/, error.message)
  end

  test "sends SESSDATA alongside the buvid on API calls when configured" do
    cookie = capture_search_cookie(sessdata: "LOGIN_COOKIE")
    assert_includes cookie, "SESSDATA=LOGIN_COOKIE"
    assert_includes cookie, "buvid3=BUVID3VALUE"
  end

  test "omits SESSDATA when not configured, still sending the buvid" do
    cookie = capture_search_cookie(sessdata: nil)
    assert_not_includes cookie.to_s, "SESSDATA"
    assert_includes cookie, "buvid3=BUVID3VALUE"
  end

  private

  # Runs a fetch with the given sessdata and returns the Cookie header that
  # reached the (signed) search request.
  def capture_search_cookie(sessdata:)
    cookie = nil
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://api.bilibili.com/x/frontend/finger/spi") { [ 200, json, SPI ] }
    stubs.get("https://api.bilibili.com/x/web-interface/nav") { [ 200, json, NAV ] }
    stubs.get("https://api.bilibili.com/x/space/wbi/arc/search") do |env|
      cookie = env.request_headers["Cookie"]
      [ 200, json, SEARCH ]
    end

    Feed::Bilibili.new(Feed.new(feed_url: SPACE_URL), http(stubs), sessdata: sessdata).fetch
    cookie
  end

  def stubbed_http
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://api.bilibili.com/x/frontend/finger/spi") { [ 200, json, SPI ] }
    stubs.get("https://api.bilibili.com/x/web-interface/nav") { [ 200, json, NAV ] }
    stubs.get("https://api.bilibili.com/x/space/wbi/arc/search") { [ 200, json, SEARCH ] }
    http(stubs)
  end

  def http(stubs)
    Faraday.new { |b| b.adapter :test, stubs }
  end

  def json
    { "Content-Type" => "application/json" }
  end
end
