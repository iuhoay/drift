class AddKindToFeeds < ActiveRecord::Migration[8.2]
  def change
    add_column :feeds, :kind, :string, null: false, default: "rss"
  end
end
