class AddCategoryToSubscriptions < ActiveRecord::Migration[8.2]
  def change
    add_column :subscriptions, :category, :string
  end
end
