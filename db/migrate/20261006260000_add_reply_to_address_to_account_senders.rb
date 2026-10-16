class AddReplyToAddressToAccountSenders < ActiveRecord::Migration[8.2]
  def change
    add_column :account_senders, :reply_to_address, :string, limit: 255
  end
end
