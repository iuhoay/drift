class AddLastActiveAtToSessions < ActiveRecord::Migration[8.2]
  def change
    add_column :sessions, :last_active_at, :datetime
  end
end
