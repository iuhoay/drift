require "test_helper"

# Covers the admin gate on the mounted Mission Control Jobs engine (Admin::BaseController).
# The dashboard's job views only render against a real Solid Queue backend (production),
# so these tests exercise the auth gate — which short-circuits before any backend query —
# rather than the engine's rendering.
class MissionControlJobsAccessTest < ActionDispatch::IntegrationTest
  test "signed-out users are denied" do
    get "/jobs"
    assert_redirected_to "/"
  end

  test "non-admin users are denied" do
    sign_in_as users(:one)
    get "/jobs"
    assert_redirected_to "/"
    assert_equal "Access denied", flash[:alert]
  end
end
