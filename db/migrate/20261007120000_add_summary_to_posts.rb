class AddSummaryToPosts < ActiveRecord::Migration[8.2]
  def change
    add_column :posts, :summary, :string, limit: 300
  end
end
