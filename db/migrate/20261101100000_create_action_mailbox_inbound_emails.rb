class CreateActionMailboxInboundEmails < ActiveRecord::Migration[8.2]
  def change
    create_table :action_mailbox_inbound_emails, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.integer :status, default: 0, null: false
      t.string :message_id, limit: 255, null: false
      t.string :message_checksum, limit: 255, null: false

      t.timestamps

      t.index :account_id
      t.index [ :message_id, :message_checksum ], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end
end
