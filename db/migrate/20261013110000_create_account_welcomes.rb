class CreateAccountWelcomes < ActiveRecord::Migration[8.2]
  def change
    create_table :account_welcomes, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.datetime :created_at, null: false

      t.index :account_id, unique: true
    end
  end
end
