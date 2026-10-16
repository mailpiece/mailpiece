class AddSubscriptionReturnUrlToAccounts < ActiveRecord::Migration[8.2]
  def change
    add_column :accounts, :subscription_return_url, :string, limit: 255
  end
end
