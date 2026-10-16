class AddNewSubscriberNotificationsToUserSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :user_settings, :new_subscriber_notifications, :boolean, default: true, null: false
  end
end
