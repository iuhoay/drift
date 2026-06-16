class AddNextFetchAtToFeeds < ActiveRecord::Migration[8.2]
  def change
    add_column :feeds, :next_fetch_at, :datetime
    add_index :feeds, :next_fetch_at
  end
end
