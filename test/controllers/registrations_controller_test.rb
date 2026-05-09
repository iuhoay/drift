require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid params signs the user in" do
    assert_difference -> { User.count } => 1 do
      post registration_path, params: {
        user: { email_address: "fresh@example.com", password: "password1", password_confirmation: "password1" }
      }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid params re-renders new" do
    assert_no_difference -> { User.count } do
      post registration_path, params: {
        user: { email_address: "bad", password: "short", password_confirmation: "short" }
      }
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id].presence
  end
end
