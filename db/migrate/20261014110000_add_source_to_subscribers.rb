class AddSourceToSubscribers < ActiveRecord::Migration[8.2]
  def change
    add_reference :subscribers, :source_post, type: :uuid
    add_column :subscribers, :referrer, :string, limit: 255
  end
end
