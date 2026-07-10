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
# impossible. We work around this without a server-side parser (zhparser/pg_jieba)
# by rewriting each CJK run into overlapping 2-grams, e.g. "搜索引擎" -> "搜索 索引
# 引擎". ASCII is left untouched, so English stemming under the 'english' config
# keeps working.
#
# The index and the query are tokenized slightly differently. `bigramize_index`
# stores both the unigrams and the bigrams of each run; `bigramize` turns a query
# into just its bigrams — or a lone unigram when the query is a single CJK
# character. That asymmetry keeps multi-character matches precise (they still
# hinge on the bigrams) while letting a single-character query match the unigrams
# the index carries.
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

  # Query form: rewrites every CJK run into space-separated overlapping bigrams,
  # leaving the rest of the string (ASCII words, punctuation) in place. A lone CJK
  # character can't form a bigram, so it stays a unigram — which the index also
  # carries, so single-character searches match.
  def self.bigramize(text)
    segment(text) { |chars| chars.size > 1 ? chars.each_cons(2).map(&:join) : chars }
  end

  # Index form of the same text: carries BOTH the unigrams and the overlapping
  # bigrams of every CJK run, so a single-character query (only ever a unigram)
  # still finds the row while multi-character queries keep matching on the more
  # precise bigrams.
  def self.bigramize_index(text)
    segment(text) { |chars| chars + chars.each_cons(2).map(&:join) }
  end

  # Rewrites each CJK run in `text` through the block, joining the returned grams
  # with spaces and leaving non-CJK text untouched.
  def self.segment(text)
    text.to_s.gsub(CJK_RUN) { |run| " #{yield(run.chars).join(' ')} " }
  end
  private_class_method :segment

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
    values = weights.keys.map { |column| Searchable.bigramize_index(public_send(column)) }

    self.search_vector = self.class.connection.select_value(
      self.class.sanitize_sql_array([ "SELECT #{sql}", *values ])
    )
  end
end
