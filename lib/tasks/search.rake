namespace :search do
  desc "Rebuild the full-text search_vector for every Searchable record (run after a tokenization change)"
  task reindex: :environment do
    [ Entry, SavedItem ].each do |model|
      count = model.count
      print "Reindexing #{model.name} (#{count} rows)... "
      model.reindex_search
      puts "done."
    end
  end
end
