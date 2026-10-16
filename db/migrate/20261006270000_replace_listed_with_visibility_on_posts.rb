class ReplaceListedWithVisibilityOnPosts < ActiveRecord::Migration[8.2]
  class Post < ActiveRecord::Base
  end

  def up
    add_column :posts, :visibility, :string, limit: 255, default: "listed", null: false

    Post.reset_column_information
    Post.where(listed: false).update_all(visibility: "unlisted")

    remove_column :posts, :listed
  end

  def down
    add_column :posts, :listed, :boolean, default: true, null: false

    Post.reset_column_information
    Post.where.not(visibility: "listed").update_all(listed: false)

    remove_column :posts, :visibility
  end
end
