require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = users(:one)
    @entry = entries(:example_first)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get entries_path
    assert_redirected_to new_session_path
  end

  test "index defaults to unread scope" do
    get entries_path
    assert_response :success

    assert_select "##{dom_id(entries(:stale_first))}"
    assert_select "##{dom_id(entries(:example_first))}", count: 0 # already read
  end

  test "index with scope=all shows every subscribed entry" do
    get entries_path, params: { scope: "all" }
    assert_response :success

    assert_select "##{dom_id(entries(:example_first))}"
    assert_select "##{dom_id(entries(:unsubscribed_first))}", count: 0
  end

  test "index with scope=starred only shows starred entries" do
    get entries_path, params: { scope: "starred" }
    assert_response :success

    assert_select "##{dom_id(entries(:example_second))}"
    assert_select "##{dom_id(entries(:stale_first))}", count: 0
  end

  test "index filters by feed" do
    get entries_path, params: { scope: "all", feed_id: feeds(:stale).id }
    assert_response :success

    assert_select "##{dom_id(entries(:stale_first))}"
    assert_select "##{dom_id(entries(:example_first))}", count: 0
  end

  test "show does not mark the entry as read on GET" do
    target = entries(:stale_first)

    # GET must stay side-effect free so Turbo's hover prefetch can't mark
    # entries read. The view POSTs to #read once it actually renders.
    assert_no_difference -> { @user.user_entries.read.count } do
      get entry_path(target)
    end

    assert_response :success
    assert_select "##{dom_id(target, :actions)}[data-controller=mark-read][data-mark-read-url-value=?]",
      entry_read_path(target)
    assert_select ".entry-content[data-controller=syntax-highlight]"
    assert_select 'link[rel="modulepreload"][href*="@shikijs"]', count: 0
  end

  test "show is scoped to subscribed entries" do
    get entry_path(entries(:unsubscribed_first))
    assert_response :not_found
  end

  test "show preserves a code block language hint for syntax highlighting" do
    @entry.update!(content: '<pre><code class="language-ruby">def answer = 42</code></pre>')

    get entry_path(@entry)

    assert_response :success
    assert_select ".entry-content[data-controller=syntax-highlight] pre > code.language-ruby",
      text: "def answer = 42"
  end
end
