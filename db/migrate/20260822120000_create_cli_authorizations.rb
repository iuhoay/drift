class CreateCliAuthorizations < ActiveRecord::Migration[8.2]
  def change
    create_table :cli_authorizations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :cli_authorizations, :code, unique: true
  end
end
