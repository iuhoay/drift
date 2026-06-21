require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "about is reachable without authentication" do
    get about_path
    assert_response :success
    assert_select "h1", "About Drift"
  end

  test "terms is reachable without authentication" do
    get terms_path
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "privacy is reachable without authentication" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "sign-up links to the legal pages" do
    get new_registration_path
    assert_response :success
    assert_select "a[href=?]", terms_path
    assert_select "a[href=?]", privacy_path
  end

  test "legal pages carry canonical and Open Graph meta" do
    get about_path
    assert_response :success
    assert_select "link[rel=canonical][href=?]", about_url
    assert_select "meta[property='og:title'][content=?]", "About — Drift"
    assert_select "meta[name=description]"
  end

  test "robots.txt is served and references the sitemap" do
    get robots_url
    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_match(/User-agent: \*/, @response.body)
    assert_match(/Sitemap: #{Regexp.escape(sitemap_url)}/, @response.body)
  end

  test "sitemap.xml lists the public pages" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, root_url
    assert_includes @response.body, about_url
  end
end
