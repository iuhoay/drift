class ReindexSearchVectorsForCjkBigrams < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Existing search_vectors were built before CJK bigram tokenization, so they
  # collapse each Chinese/Japanese/Korean run into a single unsearchable lexeme.
  # Rebuild them in place; the column and GIN index are unchanged.
  def up
    Entry.reindex_search
    SavedItem.reindex_search
  end

  def down
    # No-op: the bigram vectors remain valid and the old scheme had no benefit.
  end
end
