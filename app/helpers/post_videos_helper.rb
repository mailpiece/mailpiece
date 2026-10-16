module PostVideosHelper
  # Our copy where the post holds one, by the address that does not expire, or else YouTube's own.
  def post_video_thumbnail_url(post, video)
    if thumbnail = post.video_thumbnail(video)
      rails_storage_proxy_url(thumbnail)
    else
      video.thumbnail_address
    end
  end
end
