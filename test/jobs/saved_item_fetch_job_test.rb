require "test_helper"

class SavedItemFetchJobTest < ActiveSupport::TestCase
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

    SavedItemFetchJob.new.perform(item.id, http: stub_http(200, {}, HTML))
    item.reload

    assert_equal "Open Graph Title", item.title
    assert_equal "A concise summary of the page.", item.excerpt
    assert_equal "Example News", item.site_name
    assert_equal "https://example.com/lead.png", item.image_url
  end

  test "does not overwrite a title the extension already captured" do
    item = users(:one).saved_items.create!(url: "https://example.com/a", title: "Tab Title")

    SavedItemFetchJob.new.perform(item.id, http: stub_http(200, {}, HTML))

    assert_equal "Tab Title", item.reload.title
  end

  test "falls back to the host for site_name when no og:site_name" do
    item = users(:one).saved_items.create!(url: "https://blog.example.com/p")

    SavedItemFetchJob.new.perform(item.id, http: stub_http(200, {}, "<html><head></head></html>"))

    assert_equal "blog.example.com", item.reload.site_name
  end

  test "leaves the item alone on a non-2xx response" do
    item = users(:one).saved_items.create!(url: "https://example.com/missing", title: "Tab Title")

    SavedItemFetchJob.new.perform(item.id, http: stub_http(404))

    assert_equal "Tab Title", item.reload.title
    assert_nil item.excerpt
  end

  test "is a no-op when the item was deleted" do
    assert_nothing_raised do
      SavedItemFetchJob.new.perform(-1, http: stub_http(200, {}, HTML))
    end
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
