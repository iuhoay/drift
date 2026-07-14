class AddFullContentToEntries < ActiveRecord::Migration[8.2]
  def change
    add_column :entries, :full_content, :text
  end
end
