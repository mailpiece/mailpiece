class MoveAccountDescriptionToRichText < ActiveRecord::Migration[8.2]
  def change
    remove_column :accounts, :description, :string, limit: 500
  end
end
