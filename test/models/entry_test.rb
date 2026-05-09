require "test_helper"

class EntryTest < ActiveSupport::TestCase
  test "guid is unique within a feed but reusable across feeds" do
    feed = feeds(:example)
    duplicate = feed.entries.build(guid: entries(:example_first).guid, title: "dup")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:guid], "has already been taken"

    cross_feed = feeds(:stale).entries.build(guid: entries(:example_first).guid, title: "ok")
    assert cross_feed.valid?
  end

  test "recent orders by published_at desc with created_at fallback" do
    feed = feeds(:example)

    assert_equal [ entries(:example_second), entries(:example_first) ],
                 feed.entries.recent.to_a
  end

  test "search matches against the assigned search vector" do
    feed = feeds(:example)
    match = feed.entries.create!(guid: "search-match", title: "Searchable Foobar Title")
    miss  = feed.entries.create!(guid: "search-miss", title: "Different Words")

    results = Entry.search("foobar")

    assert_includes results, match
    assert_not_includes results, miss
  end

  test "search returns all entries when query is blank" do
    assert_equal Entry.all.to_a.sort, Entry.search("").to_a.sort
  end

  test "excerpt strips html and truncates" do
    entry = Entry.new(content: "<p>Hello <strong>world</strong>!  This  has  whitespace.</p>")

    assert_equal "Hello world! This has whitespace.", entry.excerpt
  end

  test "excerpt prefers summary over content" do
    entry = Entry.new(summary: "Just the summary.", content: "<p>Body</p>")
    assert_equal "Just the summary.", entry.excerpt
  end

  test "for_user finds or initializes a user_entry" do
    entry = entries(:example_first)
    user = users(:one)

    assert_equal user_entries(:one_example_first_read), entry.for_user(user)

    fresh = entry.for_user(users(:two))
    assert fresh.new_record?
    assert_equal users(:two), fresh.user
  end
end
