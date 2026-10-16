class Post::Revision < ApplicationRecord
  belongs_to :account, default: -> { post.account }
  belongs_to :post
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_rich_text :body

  # An image taken out of the post lives on here, and the email already sent still shows it.
  delegate :publicly_accessible?, to: :post

  scope :before, ->(revision) { where("created_at < ?", revision.created_at) }
  scope :after, ->(revision) { where("created_at > ?", revision.created_at) }

  def previous
    post.revisions.before(self).last
  end

  def next
    post.revisions.after(self).first
  end
end
