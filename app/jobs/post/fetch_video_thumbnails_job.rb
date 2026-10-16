class Post::FetchVideoThumbnailsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(post)
    post.fetch_video_thumbnails_now
  end
end
