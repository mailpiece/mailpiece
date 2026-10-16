class CreateSubscriberImports < ActiveRecord::Migration[8.2]
  def change
    create_table :subscriber_imports, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.uuid :creator_id, null: false
      t.string :status, limit: 255, default: "pending", null: false
      t.string :failure_reason, limit: 255
      t.json :rows

      t.timestamps

      t.index :account_id
      t.index :created_at
    end
  end
end
