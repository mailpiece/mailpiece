class Post::PublishDueJob < ApplicationJob
  def perform
    Post.publish_due_now
  end
end
