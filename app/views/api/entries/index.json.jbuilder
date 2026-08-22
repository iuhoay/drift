json.entries @entries do |entry|
  json.partial! "api/entries/entry", entry: entry, user_entry: @user_entries_by_id[entry.id]
end
