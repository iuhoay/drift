require "test_helper"

class Entries::ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create marks the entry as read" do
    target = entries(:stale_first)

    post entry_read_path(target), as: :turbo_stream

    assert_response :success
    assert @user.user_entries.find_by(entry: target).read?
  end

  test "destroy clears read_at" do
    target = entries(:example_first)

    delete entry_read_path(target), as: :turbo_stream

    assert_response :success
    assert_not @user.user_entries.find_by(entry: target).read?
  end

  test "create is scoped to subscribed entries" do
    post entry_read_path(entries(:unsubscribed_first)), as: :turbo_stream

    assert_response :not_found
  end

  test "html create redirects back" do
    target = entries(:stale_first)

    post entry_read_path(target), headers: { "HTTP_REFERER" => entries_url }

    assert_redirected_to entries_url
  end
end
