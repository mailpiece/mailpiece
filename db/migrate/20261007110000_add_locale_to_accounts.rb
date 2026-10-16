class AddLocaleToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :locale, :string, limit: 255
  end
end
