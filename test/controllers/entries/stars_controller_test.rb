require "test_helper"

class Entries::StarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create sets starred_at" do
    target = entries(:stale_first)

    post entry_star_path(target), as: :turbo_stream

    assert_response :success
    assert @user.user_entries.find_by(entry: target).starred?
  end

  test "destroy clears starred_at" do
    target = entries(:example_second)

    delete entry_star_path(target), as: :turbo_stream

    assert_response :success
    assert_not @user.user_entries.find_by(entry: target).starred?
  end

  test "html create redirects back" do
    target = entries(:stale_first)

    post entry_star_path(target), headers: { "HTTP_REFERER" => entries_url }

    assert_redirected_to entries_url
  end
end
