class AddWatchedToSubscriptions < ActiveRecord::Migration[8.2]
  def change
    add_column :subscriptions, :watched, :boolean, default: false, null: false
  end
end
