class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :feed, null: false, foreign_key: true
      t.string :guid, null: false
      t.string :url
      t.string :title
      t.string :author
      t.text :summary
      t.text :content
      t.datetime :published_at

      t.tsvector :search_vector

      t.timestamps
    end

    add_index :entries, [ :feed_id, :guid ], unique: true
    add_index :entries, :published_at
    add_index :entries, :search_vector, using: :gin
  end
end
