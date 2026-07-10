require "test_helper"

class SavedItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get saved_items_path
    assert_redirected_to new_session_path
  end

  test "index defaults to unread and hides read items" do
    get saved_items_path
    assert_response :success
    assert_select "##{dom_id(saved_items(:one_unread))}"
    assert_select "##{dom_id(saved_items(:one_read))}", false
  end

  test "index starred scope shows only starred" do
    get saved_items_path(scope: "starred")
    assert_response :success
    assert_select "##{dom_id(saved_items(:one_starred))}"
    assert_select "##{dom_id(saved_items(:one_unread))}", false
  end

  test "index never shows another user's items" do
    get saved_items_path(scope: "all")
    assert_response :success
    assert_select "##{dom_id(saved_items(:two_unread))}", false
  end

  test "index search filters by title" do
    @user.saved_items.create!(url: "https://example.com/searchable", title: "Findme Headline")

    get saved_items_path(q: "Findme")
    assert_response :success
    assert_select "h2", /Findme Headline/
  end

  test "show renders without marking read" do
    get saved_item_path(saved_items(:one_unread))
    assert_response :success
    assert_not saved_items(:one_unread).reload.read?
    assert_select ".entry-content[data-controller=syntax-highlight]"
  end

  test "show is scoped to the current user" do
    get saved_item_path(saved_items(:two_unread))
    assert_response :not_found
  end

  test "create saves the url and enqueues enrichment" do
    assert_difference -> { @user.saved_items.count } => 1 do
      assert_enqueued_with(job: SavedItemFetchJob) do
        post saved_items_path, params: { saved_item: { url: "https://new.example.com/post" } }
      end
    end

    assert_redirected_to saved_items_path
  end

  test "create is idempotent for an already saved url" do
    existing = saved_items(:one_unread)

    assert_no_difference -> { @user.saved_items.count } do
      assert_no_enqueued_jobs only: SavedItemFetchJob do
        post saved_items_path, params: { saved_item: { url: existing.url } }
      end
    end

    assert_redirected_to saved_items_path
  end

  test "create rejects an invalid url" do
    assert_no_difference -> { @user.saved_items.count } do
      post saved_items_path, params: { saved_item: { url: "not-a-url" } }
    end

    assert_redirected_to saved_items_path
    assert_equal flash[:alert].present?, true
  end

  test "destroy removes the item" do
    assert_difference -> { @user.saved_items.count } => -1 do
      delete saved_item_path(saved_items(:one_unread))
    end

    assert_redirected_to saved_items_path
  end

  test "cannot destroy another user's item" do
    assert_no_difference -> { SavedItem.count } do
      delete saved_item_path(saved_items(:two_unread))
    end

    assert_response :not_found
  end
end
