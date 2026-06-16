require "test_helper"

class Account::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "edit renders" do
    get edit_account_reading_path
    assert_response :success
  end

  test "update saves the reading preferences" do
    patch account_reading_path, params: {
      user: { reading_font: "serif", reading_font_size: "large" }
    }

    assert_redirected_to account_path
    users(:one).reload.tap do |user|
      assert_equal "serif", user.reading_font
      assert_equal "large", user.reading_font_size
    end
  end

  test "update with an invalid font is rejected" do
    patch account_reading_path, params: {
      user: { reading_font: "comic-sans", reading_font_size: "large" }
    }

    assert_response :unprocessable_entity
    assert_equal "mono", users(:one).reload.reading_font
  end
end
