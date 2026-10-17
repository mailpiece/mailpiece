class AddTransportToAccountSenders < ActiveRecord::Migration[8.2]
  def change
    add_column :account_senders, :transport, :string, limit: 255
    add_column :account_senders, :relay_url, :string, limit: 255
    add_column :account_senders, :relay_token, :text
    add_column :account_senders, :smtp_address, :string, limit: 255
    add_column :account_senders, :smtp_port, :integer
    add_column :account_senders, :smtp_username, :string, limit: 255
    add_column :account_senders, :smtp_password, :text
  end
end
