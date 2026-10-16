class Search::Query
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  SHORTEST_TERM = 3

  attribute :terms, :string

  validates :terms, presence: true
  before_validation :sanitize_terms

  delegate :to_s, to: :terms

  class << self
    def wrap(query)
      if query.is_a?(self)
        query
      else
        new(terms: query)
      end
    end
  end

  private
    def sanitize_terms
      self.terms = sanitize(terms)
    end

    def sanitize(terms)
      if terms.present?
        terms = remove_invalid_search_characters(terms)
        terms = remove_unbalanced_quotes(terms)
        terms = quote_every_word(terms)
        terms.presence
      else
        terms
      end
    end

    def remove_invalid_search_characters(terms)
      terms.gsub(/[^[:alnum:]"]/, " ")
    end

    def remove_unbalanced_quotes(terms)
      if terms.count("\"").even?
        terms
      else
        terms.gsub("\"", " ")
      end
    end

    # The index is trigrams, so a name is found from any three letters of it before it is typed in
    # full, and a shorter term finds nothing at all: FTS5 does not skip it, it matches no row.
    # Quoted, so a word FTS5 would read as an operator (OR, NOT, NEAR) is searched for instead.
    def quote_every_word(terms)
      terms.scan(/"[^"]*"|[^\s"]+/).map { it.delete("\"").strip }
        .select { it.length >= SHORTEST_TERM }.map { "\"#{it}\"" }.join(" ")
    end
end
