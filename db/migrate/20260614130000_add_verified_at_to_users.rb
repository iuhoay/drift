class AddVerifiedAtToUsers < ActiveRecord::Migration[8.2]
  def up
    add_column :users, :verified_at, :datetime

    # Grandfather existing users as verified so the soft email-verification
    # gate only applies to accounts created from now on.
    execute "UPDATE users SET verified_at = created_at WHERE verified_at IS NULL"
  end

  def down
    remove_column :users, :verified_at
  end
end
