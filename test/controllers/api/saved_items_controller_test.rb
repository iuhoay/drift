require "test_helper"

class Api::SavedItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = api_tokens(:one_laptop)
  end

  test "rejects a request with no token" do
    post api_saved_items_path, params: { url: "https://example.com/x" }, as: :json
    assert_response :unauthorized
  end

  test "rejects an unknown token" do
    post api_saved_items_path, params: { url: "https://example.com/x" }, as: :json,
         headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
  end

  test "creates a saved item for the token's user and enqueues enrichment" do
    assert_difference -> { @user.saved_items.count } => 1 do
      assert_enqueued_with(job: SavedItemFetchJob) do
        post api_saved_items_path,
             params: { url: "https://example.com/from-extension", title: "Tab Title" },
             as: :json, headers: auth
      end
    end

    assert_response :created
    item = @user.saved_items.find_by(url: "https://example.com/from-extension")
    assert_equal "Tab Title", item.title
  end

  test "touches the token's last_used_at" do
    freeze_time do
      post api_saved_items_path, params: { url: "https://example.com/touch" }, as: :json, headers: auth
      assert_equal Time.current, @token.reload.last_used_at
    end
  end

  test "is idempotent for an already saved url" do
    existing = saved_items(:one_unread)

    assert_no_difference -> { @user.saved_items.count } do
      post api_saved_items_path, params: { url: existing.url }, as: :json, headers: auth
    end

    assert_response :ok
  end

  test "rejects an invalid url" do
    post api_saved_items_path, params: { url: "not-a-url" }, as: :json, headers: auth
    assert_response :unprocessable_entity
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token.token}" }
  end
end
