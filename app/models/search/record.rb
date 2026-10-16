# Its id is an integer, unlike every other table: the gem upserts by searchable_type and
# searchable_id and never names an id, and search_records_fts joins on the rowid it aliases.
class Search::Record < ApplicationRecord
end
