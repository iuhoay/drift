class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :feed_url, null: false
      t.string :site_url
      t.string :title
      t.text :description
      t.string :etag
      t.string :last_modified
      t.datetime :last_fetched_at
      t.datetime :last_success_at
      t.text :last_error
      t.integer :fetch_failure_count, null: false, default: 0

      t.timestamps
    end

    add_index :feeds, :feed_url, unique: true
  end
end
