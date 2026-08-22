require "test_helper"

class Api::EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = api_tokens(:one_laptop)
  end

  test "rejects a request with no token" do
    get api_entries_path, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "rejects an unknown token" do
    get api_entries_path, as: :json, headers: { "Authorization" => "Bearer nope" }
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "default inbox is unread subscribed entries" do
    get api_entries_path, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_includes ids, entries(:stale_first).id
    assert_includes ids, entries(:example_second).id
    assert_not_includes ids, entries(:example_first).id
    assert_not_includes ids, entries(:unsubscribed_first).id
  end

  test "scope=all includes read entries and never unsubscribed ones" do
    get api_entries_path, params: { scope: "all" }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_includes ids, entries(:example_first).id
    assert_not_includes ids, entries(:unsubscribed_first).id
  end

  test "scope=starred is only starred entries" do
    get api_entries_path, params: { scope: "starred" }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_equal [ entries(:example_second).id ], ids
  end

  test "feed_id limits the list to that subscribed feed" do
    get api_entries_path, params: { scope: "all", feed_id: feeds(:stale).id }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_equal [ entries(:stale_first).id ], ids
  end

  test "limit is honored" do
    get api_entries_path, params: { limit: 1 }, as: :json, headers: auth
    assert_response :success
    assert_equal 1, response.parsed_body["entries"].size
  end

  test "rejects a QUERY with no token" do
    query api_entries_path, params: { q: "hello" }, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  test "GET q= searches subscribed entries" do
    match = feeds(:example).entries.create!(guid: "api-search-match", title: "Searchable Foobar Title")
    miss  = feeds(:example).entries.create!(guid: "api-search-miss", title: "Different Words")
    hidden = feeds(:unsubscribed).entries.create!(guid: "api-search-hidden", title: "Searchable Foobar Hidden")

    get api_entries_path, params: { q: "foobar", scope: "all" }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_equal [ match.id ], ids
    assert_not_includes ids, miss.id
    assert_not_includes ids, hidden.id
  end

  test "QUERY searches from a JSON body" do
    match = feeds(:example).entries.create!(guid: "api-query-match", title: "Searchable Foobar Title")
    miss  = feeds(:example).entries.create!(guid: "api-query-miss", title: "Different Words")

    query api_entries_path, params: { q: "foobar", scope: "all", limit: 20 }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_equal [ match.id ], ids
    assert_not_includes ids, miss.id
  end

  test "QUERY matches a single CJK character" do
    match = feeds(:example).entries.create!(guid: "api-cjk-match", title: "搜索引擎优化指南")
    miss  = feeds(:example).entries.create!(guid: "api-cjk-miss", title: "完全不同的标题")

    query api_entries_path, params: { q: "擎", scope: "all" }, as: :json, headers: auth
    assert_response :success

    ids = response.parsed_body["entries"].map { |entry| entry["id"] }
    assert_equal [ match.id ], ids
    assert_not_includes ids, miss.id
  end

  test "show returns a tag-stripped body" do
    get api_entry_path(entries(:example_first)), as: :json, headers: auth
    assert_response :success

    json = response.parsed_body
    assert_equal "The full body of the first post.", json["body"]
    assert_no_match(/<strong>/, json["body"])
    assert_equal false, json["has_full_content"]
    assert_equal true, json["read"]
    assert_equal false, json["starred"]
  end

  test "show of an unsubscribed entry is not found" do
    get api_entry_path(entries(:unsubscribed_first)), as: :json, headers: auth
    assert_response :not_found
  end

  test "show does not create a user entry or mark the entry read" do
    target = entries(:stale_first)

    assert_no_difference -> { @user.user_entries.count } do
      get api_entry_path(target), as: :json, headers: auth
    end

    assert_response :success
    assert_equal false, response.parsed_body["read"]
    assert_nil @user.user_entries.find_by(entry: target)
  end

  test "show touches the token's last_used_at" do
    freeze_time do
      get api_entry_path(entries(:example_first)), as: :json, headers: auth
      assert_equal Time.current, @token.reload.last_used_at
    end
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token.token}" }
  end
end
