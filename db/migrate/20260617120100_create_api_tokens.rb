class CreateApiTokens < ActiveRecord::Migration[8.2]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :token, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
  end
end
