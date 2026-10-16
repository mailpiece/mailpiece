class Post::Rating < ApplicationRecord
  belongs_to :account, default: -> { post.account }
  belongs_to :post
  belongs_to :subscriber

  enum :choice, %w[ liked disliked ].index_by(&:itself), validate: true
end
