# Postgres full-text search over a `search_vector` tsvector column. Each host
# declares its weighted columns, highest weight first, with `search_columns`:
#
#   search_columns title: "A", summary: "B", content: "C", author: "D"
#
# The vector is rebuilt before_save whenever one of those columns changes, and
# `search(query)` ranks matches by ts_rank. Shared by Entry (feed entries) and
# SavedItem (read-it-later captures) so both reading surfaces search identically.
#
# CJK text carries no spaces, so Postgres' default parser collapses a whole run
# of Han/Kana/Hangul characters into a single lexeme — making sub-word search
# impossible. `bigramize` works around this without a server-side parser
# (zhparser/pg_jieba) by rewriting each CJK run into overlapping 2-grams, e.g.
# "搜索引擎" -> "搜索 索引 引擎". The same transform runs on both the indexed text
# and the query, so a search for "搜索" matches. ASCII is left untouched, so
# English stemming under the 'english' config keeps working. The tradeoff is
# that single-character CJK queries don't match (they never form a 2-gram).
module Searchable
  extend ActiveSupport::Concern

  # Maximal runs of characters from scripts written without word spacing.
  CJK_RUN = /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]+/

  included do
    scope :search, ->(query) {
      next all if query.blank?

      prepared = Searchable.bigramize(query)
      where("search_vector @@ websearch_to_tsquery('english', ?)", prepared)
        .reorder(Arel.sql("ts_rank(search_vector, websearch_to_tsquery('english', #{connection.quote(prepared)})) DESC"))
    }

    before_save :assign_search_vector
  end

  # Rewrites every CJK run into space-separated overlapping bigrams, leaving the
  # rest of the string (ASCII words, punctuation) in place.
  def self.bigramize(text)
    text.to_s.gsub(CJK_RUN) do |run|
      chars = run.chars
      grams = chars.size > 1 ? chars.each_cons(2).map(&:join) : chars
      " #{grams.join(' ')} "
    end
  end

  class_methods do
    def search_columns(weights)
      @search_weights = weights
    end

    def search_weights
      @search_weights
    end

    # Recomputes search_vector for every persisted row. Needed after the
    # tokenization scheme changes, since before_save only fires on write.
    def reindex_search(batch_size: 500)
      find_each(batch_size: batch_size, &:update_search_vector!)
    end
  end

  def update_search_vector!
    recompute_search_vector
    update_column(:search_vector, search_vector)
  end

  private

  def assign_search_vector
    weights = self.class.search_weights
    return unless weights.keys.any? { |column| public_send(:"#{column}_changed?") }

    recompute_search_vector(weights)
  end

  def recompute_search_vector(weights = self.class.search_weights)
    sql = weights.values.map { |weight|
      "setweight(to_tsvector('english', coalesce(?, '')), '#{weight}')"
    }.join(" || ")
    values = weights.keys.map { |column| Searchable.bigramize(public_send(column)) }

    self.search_vector = self.class.connection.select_value(
      self.class.sanitize_sql_array([ "SELECT #{sql}", *values ])
    )
  end
end
