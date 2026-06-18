class SavedItemFetchJob < ApplicationJob
  queue_as :default

  def perform(saved_item_id)
    item = SavedItem.find_by(id: saved_item_id)
    return unless item

    SavedItem::Fetcher.call(item)
  end
end
