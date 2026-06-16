require "test_helper"

class SavedItems::StarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create stars the item" do
    target = saved_items(:one_unread)

    post saved_item_star_path(target), as: :turbo_stream

    assert_response :success
    assert target.reload.starred?
  end

  test "destroy unstars the item" do
    target = saved_items(:one_starred)

    delete saved_item_star_path(target), as: :turbo_stream

    assert_response :success
    assert_not target.reload.starred?
  end

  test "is scoped to the current user" do
    post saved_item_star_path(saved_items(:two_unread)), as: :turbo_stream
    assert_response :not_found
  end
end
