require "test_helper"

class Entry::ScraperTest < ActiveSupport::TestCase
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

  test "stores a readable full copy in full_content" do
    entry = entries(:example_first)

    Entry::Scraper.new(entry, http: stub_http(200, {}, ARTICLE_HTML)).call

    assert_includes entry.reload.full_content.to_s, "substantial paragraph of real article prose"
  end

  test "absolutizes relative links and images against the entry URL" do
    entry = entries(:example_first)

    Entry::Scraper.new(entry, http: stub_http(200, {}, ARTICLE_HTML)).call
    full_content = entry.reload.full_content.to_s

    assert_includes full_content, "https://example.com/related"
    assert_includes full_content, "https://example.com/img/photo.png"
  end

  test "leaves full_content blank for a page with no real article body" do
    entry = entries(:example_first)

    Entry::Scraper.new(entry, http: stub_http(200, {}, "<html><body><p>hi</p></body></html>")).call

    assert_nil entry.reload.full_content
  end

  test "leaves the entry alone on a non-2xx response" do
    entry = entries(:example_first)

    Entry::Scraper.new(entry, http: stub_http(404)).call

    assert_nil entry.reload.full_content
  end

  test "keeps a previously fetched copy when a refetch extracts nothing" do
    entry = entries(:example_first)
    entry.update!(full_content: "<p>the earlier full copy</p>")

    Entry::Scraper.new(entry, http: stub_http(200, {}, "<html><body><p>hi</p></body></html>")).call

    assert_equal "<p>the earlier full copy</p>", entry.reload.full_content
  end

  test "skips entries without a fetchable URL" do
    entry = entries(:example_first)
    entry.update_column(:url, nil)

    assert_nothing_raised do
      Entry::Scraper.new(entry, http: stub_http(200, {}, ARTICLE_HTML)).call
    end
    assert_nil entry.reload.full_content
  end

  test "swallows transport errors and leaves the entry untouched" do
    entry = entries(:example_first)
    failing = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get(//) { raise Faraday::TimeoutError }
      end
    end

    assert_nothing_raised { Entry::Scraper.new(entry, http: failing).call }
    assert_nil entry.reload.full_content
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
