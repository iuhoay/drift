require "test_helper"

class SavedItem::FetcherTest < ActiveSupport::TestCase
  HTML = <<~HTML
    <html>
      <head>
        <title>Fallback Title</title>
        <meta property="og:title" content="Open Graph Title">
        <meta property="og:description" content="A concise summary of the page.">
        <meta property="og:site_name" content="Example News">
        <meta property="og:image" content="/lead.png">
      </head>
      <body>...</body>
    </html>
  HTML

  test "fills blank metadata from the fetched page" do
    item = users(:one).saved_items.create!(url: "https://example.com/article")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, HTML)).call
    item.reload

    assert_equal "Open Graph Title", item.title
    assert_equal "A concise summary of the page.", item.excerpt
    assert_equal "Example News", item.site_name
    assert_equal "https://example.com/lead.png", item.image_url
  end

  test "does not overwrite a title the extension already captured" do
    item = users(:one).saved_items.create!(url: "https://example.com/a", title: "Tab Title")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, HTML)).call

    assert_equal "Tab Title", item.reload.title
  end

  test "falls back to the host for site_name when no og:site_name" do
    item = users(:one).saved_items.create!(url: "https://blog.example.com/p")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, "<html><head></head></html>")).call

    assert_equal "blog.example.com", item.reload.site_name
  end

  test "leaves the item alone on a non-2xx response" do
    item = users(:one).saved_items.create!(url: "https://example.com/missing", title: "Tab Title")

    SavedItem::Fetcher.new(item, http: stub_http(404)).call

    assert_equal "Tab Title", item.reload.title
    assert_nil item.excerpt
  end

  ARTICLE_HTML = <<~HTML
    <html><head><title>Long Read</title></head><body>
      <nav>home about contact</nav>
      <article>
        <h1>Long Read</h1>
        <p>#{"This is a substantial paragraph of real article prose worth reading. " * 12}</p>
        <p>It continues with a <a href="/related">relative link</a> and a picture <img src="/img/photo.png" alt="x">.</p>
      </article>
      <footer>copyright junk</footer>
    </body></html>
  HTML

  test "extracts readable article body into the reader view" do
    item = users(:one).saved_items.create!(url: "https://blog.example.com/post")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, ARTICLE_HTML)).call

    assert_includes item.reload.content.to_s, "substantial paragraph of real article prose"
  end

  test "absolutizes relative links and images in extracted content" do
    item = users(:one).saved_items.create!(url: "https://blog.example.com/post")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, ARTICLE_HTML)).call
    content = item.reload.content.to_s

    assert_includes content, "https://blog.example.com/related"
    assert_includes content, "https://blog.example.com/img/photo.png"
  end

  test "leaves content blank for a page with no real article body" do
    item = users(:one).saved_items.create!(url: "https://example.com/thin")

    SavedItem::Fetcher.new(item, http: stub_http(200, {}, "<html><body><p>hi</p></body></html>")).call

    assert_nil item.reload.content
  end

  private

  def stub_http(status, headers = {}, body = "")
    Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get(//) { [ status, headers, body ] }
      end
    end
  end
end
