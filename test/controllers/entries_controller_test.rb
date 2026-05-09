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

  test "show marks the entry as read" do
    target = entries(:stale_first)

    assert_difference -> { @user.user_entries.read.count } => 1 do
      get entry_path(target)
    end

    assert_response :success
  end

  test "show is scoped to subscribed entries" do
    get entry_path(entries(:unsubscribed_first))
    assert_response :not_found
  end

  test "read marks the entry as read" do
    target = entries(:stale_first)

    post read_entry_path(target), as: :turbo_stream

    assert_response :success
    assert @user.user_entries.find_by(entry: target).read?
  end

  test "unread clears read_at" do
    post unread_entry_path(@entry), as: :turbo_stream

    assert_response :success
    assert_not @user.user_entries.find_by(entry: @entry).read?
  end

  test "star sets starred_at" do
    target = entries(:stale_first)

    post star_entry_path(target), as: :turbo_stream

    assert_response :success
    assert @user.user_entries.find_by(entry: target).starred?
  end

  test "unstar clears starred_at" do
    target = entries(:example_second)

    post unstar_entry_path(target), as: :turbo_stream

    assert_response :success
    assert_not @user.user_entries.find_by(entry: target).starred?
  end

  test "html star action redirects back" do
    target = entries(:stale_first)

    post star_entry_path(target), headers: { "HTTP_REFERER" => entries_url }

    assert_redirected_to entries_url
  end
end
