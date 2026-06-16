require "test_helper"

class SavedItems::ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create marks the item read" do
    target = saved_items(:one_unread)

    post saved_item_read_path(target), as: :turbo_stream

    assert_response :success
    assert target.reload.read?
  end

  test "destroy clears read_at" do
    target = saved_items(:one_read)

    delete saved_item_read_path(target), as: :turbo_stream

    assert_response :success
    assert_not target.reload.read?
  end

  test "is scoped to the current user" do
    post saved_item_read_path(saved_items(:two_unread)), as: :turbo_stream
    assert_response :not_found
  end

  test "html create redirects back" do
    target = saved_items(:one_unread)

    post saved_item_read_path(target), headers: { "HTTP_REFERER" => saved_items_url }

    assert_redirected_to saved_items_url
  end
end
