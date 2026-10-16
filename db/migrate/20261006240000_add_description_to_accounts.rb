class AddDescriptionToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :description, :string, limit: 500
  end
end
