require "test_helper"

class ThemesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "update requires authentication" do
    sign_out
    patch theme_path
    assert_redirected_to new_session_path
  end

  test "cycles auto -> light -> dark -> auto" do
    patch theme_path
    assert_equal "light", cookies[:theme]

    patch theme_path
    assert_equal "dark", cookies[:theme]

    patch theme_path
    assert_nil cookies[:theme].presence
  end

  test "redirects back to the referrer" do
    patch theme_path, headers: { "HTTP_REFERER" => entries_url(scope: "starred") }
    assert_redirected_to entries_url(scope: "starred")
  end

  test "redirects to root when no referrer" do
    patch theme_path
    assert_redirected_to root_path
  end
end
