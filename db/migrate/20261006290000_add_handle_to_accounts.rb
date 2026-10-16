class AddHandleToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :handle, :string, limit: 255
    add_index :accounts, :handle, unique: true
  end
end
