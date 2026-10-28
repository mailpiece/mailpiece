class DropPostRatings < ActiveRecord::Migration[8.2]
  def up
    drop_table :post_ratings
  end

  def down
    create_table :post_ratings, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :post_id, null: false
      t.uuid :subscriber_id, null: false
      t.string :choice, limit: 255, null: false
      t.timestamps

      t.index %i[ post_id subscriber_id ], unique: true
      t.index :subscriber_id
    end
  end
end
