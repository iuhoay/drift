require "test_helper"

class SavedItemTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "valid with a user and http url" do
    assert @user.saved_items.new(url: "https://example.com/x").valid?
  end

  test "requires a url" do
    item = @user.saved_items.new(url: "")
    assert_not item.valid?
    assert_includes item.errors[:url], "can't be blank"
  end

  test "rejects a non-http url" do
    assert_not @user.saved_items.new(url: "ftp://example.com/x").valid?
    assert_not @user.saved_items.new(url: "javascript:alert(1)").valid?
  end

  test "strips surrounding whitespace from the url" do
    item = @user.saved_items.create!(url: "  https://example.com/trim  ")
    assert_equal "https://example.com/trim", item.url
  end

  test "url is unique per user but not across users" do
    @user.saved_items.create!(url: "https://example.com/dup")

    dup = @user.saved_items.new(url: "https://example.com/dup")
    assert_not dup.valid?

    other = users(:two).saved_items.new(url: "https://example.com/dup")
    assert other.valid?
  end

  test "assigns saved_at on create when missing" do
    freeze_time do
      item = @user.saved_items.create!(url: "https://example.com/now")
      assert_equal Time.current, item.saved_at
    end
  end

  test "read and star state flows through Readable" do
    item = @user.saved_items.create!(url: "https://example.com/state")

    assert_not item.read?
    item.mark_read!
    assert item.read?
    item.mark_unread!
    assert_not item.read?

    item.mark_starred!
    assert item.starred?
  end

  test "search matches the title" do
    match = @user.saved_items.create!(url: "https://example.com/s", title: "Distinctive Headline")
    @user.saved_items.create!(url: "https://example.com/other", title: "Unrelated")

    results = @user.saved_items.search("Distinctive")
    assert_includes results, match
    assert_equal 1, results.count
  end

  test "search matches the extracted content body" do
    match = @user.saved_items.create!(url: "https://example.com/c", content: "<p>quantum entanglement explained</p>")

    assert_includes @user.saved_items.search("entanglement"), match
  end

  test "recent orders newest saved first" do
    ordered = @user.saved_items.recent.to_a
    assert_equal ordered.sort_by(&:saved_at).reverse, ordered
  end
end
