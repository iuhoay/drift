require "test_helper"

class Account::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  test "destroy disconnects the user's own identity" do
    sign_in_as users(:two)

    assert_difference -> { Identity.count } => -1 do
      delete account_identity_path(identities(:two_github))
    end

    assert_redirected_to account_path
  end

  test "cannot destroy another user's identity" do
    sign_in_as users(:one)

    assert_no_difference -> { Identity.count } do
      delete account_identity_path(identities(:two_github))
    end

    assert_response :not_found
  end
end
