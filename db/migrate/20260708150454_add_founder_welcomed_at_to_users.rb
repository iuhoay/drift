class AddFounderWelcomedAtToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :founder_welcomed_at, :datetime
  end
end
