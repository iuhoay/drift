class CreateUserEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :user_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.datetime :read_at
      t.datetime :starred_at

      t.timestamps
    end

    add_index :user_entries, [ :user_id, :entry_id ], unique: true
    add_index :user_entries, [ :user_id, :read_at ]
    add_index :user_entries, [ :user_id, :starred_at ]
  end
end
