class AddContentToSavedItems < ActiveRecord::Migration[8.2]
  def change
    add_column :saved_items, :content, :text
  end
end
