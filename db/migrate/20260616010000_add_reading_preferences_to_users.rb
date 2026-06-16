class AddReadingPreferencesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :reading_font, :string, null: false, default: "mono"
    add_column :users, :reading_font_size, :string, null: false, default: "medium"
  end
end
