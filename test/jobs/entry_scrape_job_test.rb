require "test_helper"

class EntryScrapeJobTest < ActiveJob::TestCase
  include ActionView::RecordIdentifier
  include Turbo::Broadcastable::TestHelper

  ARTICLE_HTML = <<~HTML
    <html><body><article>
      <p>#{"Enough real article prose to clear the extraction threshold. " * 12}</p>
    </article></body></html>
  HTML

  test "perform stores the full text and broadcasts the new body to the entry page" do
    entry = entries(:example_first)

    streams = capture_turbo_stream_broadcasts(entry) do
      stub_http_connection(200, ARTICLE_HTML) { EntryScrapeJob.perform_now(entry.id) }
    end

    assert_includes entry.reload.full_content.to_s, "Enough real article prose"

    replace = streams.find { |stream| stream["action"] == "replace" }
    assert_equal dom_id(entry, :body), replace["target"]
    assert_includes replace.to_html, "Enough real article prose"

    remove = streams.find { |stream| stream["action"] == "remove" }
    assert_equal dom_id(entry, :full_content_request), remove["target"]
  end

  test "perform broadcasts a failure note when no readable copy could be extracted" do
    entry = entries(:example_first)

    streams = capture_turbo_stream_broadcasts(entry) do
      stub_http_connection(200, "<html><body><p>hi</p></body></html>") { EntryScrapeJob.perform_now(entry.id) }
    end

    assert_nil entry.reload.full_content

    assert_equal 1, streams.size
    assert_equal "replace", streams.first["action"]
    assert_equal dom_id(entry, :full_content_request), streams.first["target"]
    assert_match(/couldn't extract a readable copy/i, streams.first.to_html)
  end

  test "performing with a missing entry is a no-op" do
    assert_nothing_raised do
      EntryScrapeJob.perform_now(0)
    end
  end

  private

  # Swaps Feed.http_connection for a canned Faraday test adapter for the block,
  # the same manual pattern as stub_discovery (Minitest 6 has no Object#stub).
  def stub_http_connection(status, body)
    connection = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get(//) { [ status, {}, body ] }
      end
    end

    original = Feed.method(:http_connection)
    Feed.define_singleton_method(:http_connection) { connection }
    yield
  ensure
    Feed.define_singleton_method(:http_connection, original)
  end
end
