class CreateWebSubSubscriptions < ActiveRecord::Migration[8.2]
  def change
    create_table :web_sub_subscriptions do |t|
      t.references :feed, null: false, foreign_key: true, index: { unique: true }
      t.string :callback_token, null: false
      t.string :secret, null: false
      t.string :state, null: false, default: "pending"
      t.datetime :lease_expires_at
      t.datetime :verified_at
      t.datetime :last_delivery_at

      t.timestamps
    end

    add_index :web_sub_subscriptions, :callback_token, unique: true
    add_index :web_sub_subscriptions, :lease_expires_at
  end
end
