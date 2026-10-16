class CreateSearchRecords < ActiveRecord::Migration[8.2]
  def change
    # An integer id, not a uuid: ActiveSearch upserts by searchable_type and searchable_id without
    # naming one, and search_records_fts joins on the rowid it aliases.
    create_table :search_records do |t|
      t.string :searchable_type, limit: 255, null: false
      t.uuid :searchable_id, null: false
      t.uuid :account_id, null: false
      t.index :account_id
      t.index [ :searchable_type, :searchable_id ], unique: true
    end

    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE VIRTUAL TABLE search_records_fts USING fts5(
            title,
            content,
            tokenize='trigram remove_diacritics 1'
          )
        SQL
      end

      direction.down { execute "DROP TABLE search_records_fts" }
    end
  end
end
