class AddDeadAtToFeeds < ActiveRecord::Migration[8.2]
  def change
    add_column :feeds, :dead_at, :datetime
  end
end
