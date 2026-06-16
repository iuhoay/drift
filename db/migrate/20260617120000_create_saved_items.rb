class CreateSavedItems < ActiveRecord::Migration[8.2]
  def change
    create_table :saved_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url, null: false
      t.string :title
      t.text :excerpt
      t.string :site_name
      t.string :image_url
      t.datetime :saved_at, null: false
      t.datetime :read_at
      t.datetime :starred_at
      t.tsvector :search_vector

      t.timestamps
    end

    add_index :saved_items, [ :user_id, :url ], unique: true
    add_index :saved_items, [ :user_id, :saved_at ]
    add_index :saved_items, [ :user_id, :read_at ]
    add_index :saved_items, [ :user_id, :starred_at ]
    add_index :saved_items, :search_vector, using: :gin
  end
end
