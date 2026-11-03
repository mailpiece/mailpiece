class AddReplyForwardingToUserSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :user_settings, :reply_forwarding, :boolean, default: true, null: false
  end
end
