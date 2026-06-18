require "test_helper"

class SavedItemFetchJobTest < ActiveJob::TestCase
  test "is enqueued on the default queue" do
    item = users(:one).saved_items.create!(url: "https://example.com/article")

    assert_enqueued_with(job: SavedItemFetchJob, queue: "default", args: [ item.id ]) do
      SavedItemFetchJob.perform_later(item.id)
    end
  end

  test "performing with a missing saved item is a no-op" do
    assert_nothing_raised do
      SavedItemFetchJob.perform_now(0)
    end
  end
end
