class AddListedToPosts < ActiveRecord::Migration[8.2]
  def change
    add_column :posts, :listed, :boolean, default: true, null: false
  end
end
