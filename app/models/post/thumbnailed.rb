# A post keeps a copy of the thumbnail of each video it pictures, named for the video. A copy outlives its link
# and goes with the post.
module Post::Thumbnailed
  extend ActiveSupport::Concern

  included do
    has_many_attached :video_thumbnails

    after_save_commit :fetch_video_thumbnails_later, if: -> { videos_without_thumbnail.any? }
  end

  def video_thumbnail(video)
    video_thumbnails_blobs.find_by(filename: thumbnail_filename(video))
  end

  def fetch_video_thumbnails_later
    Post::FetchVideoThumbnailsJob.perform_later(self)
  end

  def fetch_video_thumbnails_now
    videos_without_thumbnail.each do |video|
      if image = video.download_thumbnail
        # A blob takes its account from Current, and the sweep that publishes a scheduled post queues its jobs with none.
        Current.with_account(account) do
          video_thumbnails.attach io: StringIO.new(image), filename: thumbnail_filename(video), content_type: "image/jpeg"
        end
      end
    end
  end

  private
    def videos_without_thumbnail
      videos.reject { |video| video_thumbnail(video) }
    end

    def videos
      if content = body.body
        Post::Video.all_in(content.fragment).uniq(&:id)
      else
        []
      end
    end

    def thumbnail_filename(video)
      "#{video.id}.jpg"
    end
end
