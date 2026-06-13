require "test_helper"

class UserEntryTest < ActiveSupport::TestCase
  test "read scope contains entries with read_at set" do
    assert_includes UserEntry.read, user_entries(:one_example_first_read)
    assert_not_includes UserEntry.read, user_entries(:one_example_second_starred)
  end

  test "unread scope contains entries with read_at nil" do
    assert_includes UserEntry.unread, user_entries(:one_example_second_starred)
    assert_not_includes UserEntry.unread, user_entries(:one_example_first_read)
  end

  test "starred scope contains entries with starred_at set" do
    assert_includes UserEntry.starred, user_entries(:one_example_second_starred)
    assert_not_includes UserEntry.starred, user_entries(:one_example_first_read)
  end

  test "mark_read! sets read_at when previously unread" do
    user_entry = user_entries(:one_example_second_starred)

    freeze_time do
      assert_changes -> { user_entry.read_at }, from: nil, to: Time.current do
        user_entry.mark_read!
      end
    end
  end

  test "mark_read! is a no-op when already read" do
    user_entry = user_entries(:one_example_first_read)

    assert_no_changes -> { user_entry.reload.read_at } do
      user_entry.mark_read!
    end
  end

  test "mark_unread! clears read_at" do
    user_entry = user_entries(:one_example_first_read)

    assert_changes -> { user_entry.read_at }, to: nil do
      user_entry.mark_unread!
    end
  end

  test "mark_starred! sets starred_at when previously unstarred" do
    user_entry = user_entries(:one_example_first_read)

    freeze_time do
      assert_changes -> { user_entry.starred_at }, from: nil, to: Time.current do
        user_entry.mark_starred!
      end
    end
  end

  test "mark_starred! is a no-op when already starred" do
    user_entry = user_entries(:one_example_second_starred)

    assert_no_changes -> { user_entry.reload.starred_at } do
      user_entry.mark_starred!
    end
  end

  test "mark_unstarred! clears starred_at" do
    user_entry = user_entries(:one_example_second_starred)

    assert_changes -> { user_entry.starred_at }, to: nil do
      user_entry.mark_unstarred!
    end
  end
end
