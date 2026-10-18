require "test_helper"

class Api::Entries::ReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = api_tokens(:one_laptop)
  end

  test "create marks the entry as read" do
    target = entries(:stale_first)

    post api_entry_read_path(target), as: :json, headers: auth

    assert_response :success
    json = response.parsed_body
    assert_equal target.id, json["id"]
    assert_equal true, json["read"]
    assert_not_nil json["read_at"]
    assert @user.user_entries.find_by(entry: target).read?
  end

  test "destroy clears read_at" do
    target = entries(:example_first)

    delete api_entry_read_path(target), as: :json, headers: auth

    assert_response :success
    json = response.parsed_body
    assert_equal target.id, json["id"]
    assert_equal false, json["read"]
    assert_nil json["read_at"]
    assert_not @user.user_entries.find_by(entry: target).read?
  end

  test "create of an unsubscribed entry is not found" do
    post api_entry_read_path(entries(:unsubscribed_first)), as: :json, headers: auth

    assert_response :not_found
  end

  test "rejects a request with no token" do
    post api_entry_read_path(entries(:stale_first)), as: :json

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token.token}" }
  end
end
