class AllowPostsWithoutATitle < ActiveRecord::Migration[8.2]
  def change
    change_column_null :posts, :title, true
  end
end
