require "test_helper"

class Entries::FullContentsControllerTest < ActionDispatch::IntegrationTest
  ARTICLE_HTML = <<~HTML
    <html><body><article>
      <p>#{"Enough real article prose to clear the extraction threshold. " * 12}</p>
    </article></body></html>
  HTML

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create fetches and stores the full text, then returns to the entry" do
    entry = entries(:example_first)

    stub_http_connection(200, ARTICLE_HTML) do
      post entry_full_content_path(entry)
    end

    assert_redirected_to entry_path(entry)
    assert_includes entry.reload.full_content.to_s, "Enough real article prose"
  end

  test "create alerts when no readable copy could be extracted" do
    entry = entries(:example_first)

    stub_http_connection(200, "<html><body><p>hi</p></body></html>") do
      post entry_full_content_path(entry)
    end

    assert_redirected_to entry_path(entry)
    assert_match(/couldn't extract/i, flash[:alert])
    assert_nil entry.reload.full_content
  end

  test "create is scoped to subscribed entries" do
    post entry_full_content_path(entries(:unsubscribed_first))

    assert_response :not_found
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
