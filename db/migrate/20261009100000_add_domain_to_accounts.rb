class AddDomainToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :domain, :string, limit: 255
    add_index :accounts, :domain, unique: true
  end
end
