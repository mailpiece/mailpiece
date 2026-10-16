class AddClaimedAtToPostDeliveries < ActiveRecord::Migration[8.2]
  def change
    add_column :post_deliveries, :claimed_at, :datetime

    remove_index :post_deliveries, %i[ sent_at refused_at deliver_at ], name: "index_post_deliveries_on_pending"
    add_index :post_deliveries, %i[ sent_at refused_at claimed_at deliver_at ], name: "index_post_deliveries_on_pending"
  end
end
