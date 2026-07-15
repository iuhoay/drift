require "test_helper"

class Entries::FullContentsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create enqueues a scrape and swaps the button for a pending state" do
    entry = entries(:example_first)

    assert_enqueued_with(job: EntryScrapeJob, args: [ entry.id ]) do
      post entry_full_content_path(entry), as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(entry, :full_content_request)
    assert_match(/fetching full text/i, response.body)
  end

  test "create without turbo enqueues and returns to the entry" do
    entry = entries(:example_first)

    assert_enqueued_with(job: EntryScrapeJob, args: [ entry.id ]) do
      post entry_full_content_path(entry), headers: { "Accept" => "text/html" }
    end

    assert_redirected_to entry_path(entry)
  end

  test "create is scoped to subscribed entries" do
    assert_no_enqueued_jobs do
      post entry_full_content_path(entries(:unsubscribed_first))
    end

    assert_response :not_found
  end
end
