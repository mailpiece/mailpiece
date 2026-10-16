class CreatePostLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :post_links, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :post_id, null: false
      t.string :code, limit: 8, null: false
      t.text :original_url, null: false
      t.text :url, null: false
      t.string :text, limit: 255

      t.timestamps

      t.index %i[ account_id code ], unique: true
      t.index %i[ post_id original_url ], unique: true
    end
  end
end
