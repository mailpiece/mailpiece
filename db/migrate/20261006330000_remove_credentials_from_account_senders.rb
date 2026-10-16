class RemoveCredentialsFromAccountSenders < ActiveRecord::Migration[8.2]
  def change
    remove_column :account_senders, :sending_token, :text, limit: 65535
    remove_column :account_senders, :webhook_secret, :text, limit: 65535
  end
end
