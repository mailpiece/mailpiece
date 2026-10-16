class AddDeactivatedAtToSubscribers < ActiveRecord::Migration[8.2]
  def change
    add_column :subscribers, :deactivated_at, :datetime
  end
end
