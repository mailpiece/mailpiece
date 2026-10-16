class AddCodeToPosts < ActiveRecord::Migration[8.2]
  class Post < ActiveRecord::Base
  end

  def up
    add_column :posts, :code, :string, limit: 8

    Post.reset_column_information
    Post.find_each do |post|
      post.update_columns code: SecureRandom.hex(4)
    end

    change_column_null :posts, :code, false
    add_index :posts, %i[ account_id code ], unique: true

    remove_index :posts, %i[ account_id slug ]
    remove_column :posts, :slug
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
