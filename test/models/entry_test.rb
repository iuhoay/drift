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

  test "search matches a Chinese sub-word via bigram tokenization" do
    feed = feeds(:example)
    match = feed.entries.create!(guid: "cjk-match", title: "搜索引擎优化指南")
    miss  = feed.entries.create!(guid: "cjk-miss", title: "完全不同的标题")

    results = Entry.search("引擎") # an interior 2-gram of the title

    assert_includes results, match
    assert_not_includes results, miss
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

  test "youtube_video_id extracts the id from supported URL shapes" do
    {
      "https://www.youtube.com/watch?v=sMxskir7Rug"          => "sMxskir7Rug",
      "https://www.youtube.com/watch?v=abc12345678&t=42s"    => "abc12345678",
      "https://m.youtube.com/watch?v=abc12345678"            => "abc12345678",
      "https://youtu.be/sMxskir7Rug"                         => "sMxskir7Rug",
      "https://www.youtube.com/shorts/abc12345678"           => "abc12345678",
      "https://www.youtube-nocookie.com/embed/abc12345678"   => "abc12345678"
    }.each do |url, expected|
      assert_equal expected, Entry.new(url: url).youtube_video_id, "failed for #{url}"
    end
  end

  test "youtube_video_id returns nil for non-YouTube urls" do
    assert_nil Entry.new(url: "https://daringfireball.net/2026/05/post").youtube_video_id
    assert_nil Entry.new(url: nil).youtube_video_id
    assert_nil Entry.new(url: "https://evil.example/?next=https://youtube.com/watch?v=abc12345678").youtube_video_id
  end

  test "bilibili_bvid extracts the BV id from a video URL" do
    assert_equal "BV1wPJH6UEVL", Entry.new(url: "https://www.bilibili.com/video/BV1wPJH6UEVL").bilibili_bvid
    assert_equal "BV1wPJH6UEVL", Entry.new(url: "https://www.bilibili.com/video/BV1wPJH6UEVL/?spm_id_from=x").bilibili_bvid
  end

  test "bilibili_bvid returns nil for non-Bilibili urls" do
    assert_nil Entry.new(url: "https://space.bilibili.com/26846937").bilibili_bvid
    assert_nil Entry.new(url: nil).bilibili_bvid
    assert_nil Entry.new(url: "https://evil.example/?next=https://www.bilibili.com/video/BV1wPJH6UEVL").bilibili_bvid
  end
end
