require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "generates a token on create" do
    token = @user.api_tokens.create!(name: "New")
    assert token.token.present?
  end

  test "tokens are unique" do
    a = @user.api_tokens.create!(name: "A")
    b = @user.api_tokens.create!(name: "B")
    assert_not_equal a.token, b.token
  end

  test "masked reveals only the last four characters" do
    token = api_tokens(:one_laptop)
    assert_equal "••••aaaa", token.masked
  end

  test "touch_last_used! stamps last_used_at" do
    token = api_tokens(:one_laptop)
    assert_nil token.last_used_at

    freeze_time do
      token.touch_last_used!
      assert_equal Time.current, token.reload.last_used_at
    end
  end
end
