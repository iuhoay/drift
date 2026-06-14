require "test_helper"

class Feed::DiscoveryTest < ActiveSupport::TestCase
  RSS = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Example</title>
        <link>https://example.com</link>
        <description>An example feed</description>
        <item><title>Hello</title><link>https://example.com/hello</link></item>
      </channel>
    </rss>
  XML

  test "returns the url directly when it already serves a feed" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/feed.xml") { [ 200, { "Content-Type" => "application/rss+xml" }, RSS ] }

    assert_equal [ "https://example.com/feed.xml" ], discover("https://example.com/feed.xml", stubs)
  end

  test "discovers a feed link advertised in the page HTML" do
    html = <<~HTML
      <html><head>
        <link rel="alternate" type="application/rss+xml" href="https://example.com/blog/atom.xml">
      </head><body></body></html>
    HTML

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/blog/") { [ 200, { "Content-Type" => "text/html" }, html ] }

    assert_equal [ "https://example.com/blog/atom.xml" ], discover("https://example.com/blog/", stubs)
  end

  test "does not mistake an HTML page for a feed and prefers its feed link" do
    # An HTML homepage whose markup contains <rss>/<channel> tokens (e.g. an
    # embedded widget) — Feedjira's heuristics will "parse" it, but it has no
    # entries, so discovery must return the advertised feed link, not the page.
    html = <<~HTML
      <html><head>
        <title>Blog</title>
        <link rel="alternate" type="application/atom+xml" href="https://example.com/blog/atom.xml">
      </head><body>
        <rss version="2.0"><channel><title>widget</title></channel></rss>
      </body></html>
    HTML

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/blog/") { [ 200, { "Content-Type" => "text/html" }, html ] }

    assert_equal [ "https://example.com/blog/atom.xml" ], discover("https://example.com/blog/", stubs)
  end

  test "resolves relative feed links against the page url" do
    html = <<~HTML
      <html><head>
        <link rel="alternate" type="application/atom+xml" href="atom.xml">
      </head></html>
    HTML

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/blog/") { [ 200, { "Content-Type" => "text/html" }, html ] }

    assert_equal [ "https://example.com/blog/atom.xml" ], discover("https://example.com/blog/", stubs)
  end

  test "probes conventional paths when the page advertises no feed" do
    html = "<html><head><title>No feed here</title></head><body></body></html>"

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/blog/") { [ 200, { "Content-Type" => "text/html" }, html ] }
    stubs.get("https://example.com/blog/feed") { [ 200, { "Content-Type" => "application/rss+xml" }, RSS ] }

    assert_equal [ "https://example.com/blog/feed" ], discover("https://example.com/blog/", stubs)
  end

  test "returns nothing when no feed can be found" do
    html = "<html><head><title>Nothing</title></head><body></body></html>"

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/blog/") { [ 200, { "Content-Type" => "text/html" }, html ] }
    # No conventional path is stubbed, so each probe raises and is treated as a miss.

    assert_empty discover("https://example.com/blog/", stubs)
  end

  test "blank input yields nothing" do
    assert_empty Feed::Discovery.new("   ").call
  end

  private

  def discover(url, stubs)
    http = Faraday.new { |b| b.adapter :test, stubs }
    Feed::Discovery.new(url, http: http).call
  end
end
