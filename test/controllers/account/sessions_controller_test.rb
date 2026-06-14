require "test_helper"

class Account::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @current_session = Current.session
  end

  test "index lists each of the user's sessions" do
    @user.sessions.create!(user_agent: "Mozilla/5.0 (Macintosh) Chrome/120", ip_address: "1.2.3.4")

    get account_sessions_path
    assert_response :success
    @user.sessions.each do |session|
      assert_select "##{dom_id(session)}"
    end
  end

  test "destroy revokes another session and stays signed in" do
    other = @user.sessions.create!

    assert_difference -> { @user.sessions.count } => -1 do
      delete account_session_path(other)
    end

    assert_redirected_to account_sessions_path
    assert cookies[:session_id].present?
  end

  test "destroying the current session signs the user out" do
    delete account_session_path(@current_session)

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
    assert_not Session.exists?(@current_session.id)
  end

  test "destroy_others keeps only the current session" do
    3.times { @user.sessions.create! }

    delete account_other_sessions_path

    assert_redirected_to account_sessions_path
    assert_equal [ @current_session.id ], @user.sessions.pluck(:id)
  end
end
