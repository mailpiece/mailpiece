class CreateSnippets < ActiveRecord::Migration[8.2]
  def change
    create_table :snippets, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :name, limit: 255, null: false

      t.timestamps

      t.index :account_id
    end
  end
end
