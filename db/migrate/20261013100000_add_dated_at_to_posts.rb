class AddDatedAtToPosts < ActiveRecord::Migration[8.2]
  class Post < ActiveRecord::Base
  end

  def up
    add_column :posts, :dated_at, :datetime

    Post.reset_column_information
    Post.where.not(published_at: nil).or(Post.where.not(scheduled_posting_at: nil)).find_each do |post|
      post.update_columns dated_at: post.published_at || post.scheduled_posting_at
    end

    add_index :posts, %i[ account_id dated_at ]
  end

  def down
    remove_index :posts, %i[ account_id dated_at ]
    remove_column :posts, :dated_at
  end
end
