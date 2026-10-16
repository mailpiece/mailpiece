ActiveSearch.define_index(:searchable, polymorphic: true, document_class: "Search::Record") do
  text :title
  text :content
  string :account_id
  string :searchable_type
  string :searchable_id
end
