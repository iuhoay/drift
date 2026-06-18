# Postgres full-text search over a `search_vector` tsvector column. Each host
# declares its weighted columns, highest weight first, with `search_columns`:
#
#   search_columns title: "A", summary: "B", content: "C", author: "D"
#
# The vector is rebuilt before_save whenever one of those columns changes, and
# `search(query)` ranks matches by ts_rank. Shared by Entry (feed entries) and
# SavedItem (read-it-later captures) so both reading surfaces search identically.
module Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) {
      next all if query.blank?

      where("search_vector @@ websearch_to_tsquery('english', ?)", query)
        .reorder(Arel.sql("ts_rank(search_vector, websearch_to_tsquery('english', #{connection.quote(query)})) DESC"))
    }

    before_save :assign_search_vector
  end

  class_methods do
    def search_columns(weights)
      @search_weights = weights
    end

    def search_weights
      @search_weights
    end
  end

  private

  def assign_search_vector
    weights = self.class.search_weights
    return unless weights.keys.any? { |column| public_send(:"#{column}_changed?") }

    sql = weights.values.map { |weight|
      "setweight(to_tsvector('english', coalesce(?, '')), '#{weight}')"
    }.join(" || ")
    values = weights.keys.map { |column| public_send(column) }

    self.search_vector = self.class.connection.select_value(
      self.class.sanitize_sql_array([ "SELECT #{sql}", *values ])
    )
  end
end
