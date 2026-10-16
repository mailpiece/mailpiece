module PostMailerHelper
  EMAIL_IMAGE_WIDTH = 600
  YOUTUBE_THUMBNAIL_WIDTH = 480

  def post_email_html(post)
    post.html_in_email do |part|
      case part
      when ActionText::Attachment then post_email_attachment(part, post)
      when Post::Video then post_email_youtube_poster(part, post)
      when Post::Link then public_link_url(part.code)
      end
    end
  end

  def post_email_text(post)
    post.text_in_email do |part|
      case part
      when ActionText::Attachment then post_email_text_attachment(part, post)
      when Post::Link then public_link_url(part.code)
      end
    end
  end

  private
    def post_email_attachment(attachment, post)
      attachable = attachment.attachable

      if attachable.is_a?(ActionText::Attachables::RemoteImage)
        post_email_image attachable.url, attachment
      elsif attachable.is_a?(ActiveStorage::Blob) && attachable.image?
        post_email_image rails_storage_proxy_url(attachable), attachment
      elsif attachable.is_a?(ActiveStorage::Blob) && attachable.video?
        post_email_video_poster attachable, attachment, post
      elsif attachable.is_a?(ActiveStorage::Blob)
        tag.p link_to(attachment.caption || attachable.filename.to_s, rails_storage_proxy_url(attachable, disposition: :attachment))
      else
        tag.p attachment.to_plain_text
      end
    end

    def post_email_image(url, attachment)
      render "mailers/post_mailer/image", url: url, attachment: attachment, width: post_email_image_width(attachment)
    end

    def post_email_image_width(attachment)
      if width = attachment.node["width"].presence
        [ width.to_i, EMAIL_IMAGE_WIDTH ].min
      end
    end

    # The preview is the one the web page shows. It needs ffmpeg, so without it the picture is the file's name.
    def post_email_video_poster(blob, attachment, post)
      render "mailers/post_mailer/poster", url: post_email_video_url(blob, post), caption: t("mailers_issue_watch_video"),
        title: attachment.caption || blob.filename.to_s, width: post_email_image_width(attachment),
        picture: (rails_storage_proxy_url(blob.preview(Attachments::VARIANTS[:large])) if blob.previewable?)
    end

    def post_email_youtube_poster(video, post)
      render "mailers/post_mailer/poster", url: video.address, caption: video.caption,
        title: t("mailers_issue_youtube_alt"), width: YOUTUBE_THUMBNAIL_WIDTH, picture: post_video_thumbnail_url(post, video)
    end

    def post_email_video_url(blob, post)
      if post.on_the_web?
        public_post_url(post.public_param)
      else
        rails_storage_proxy_url(blob)
      end
    end

    def post_email_text_attachment(attachment, post)
      attachable = attachment.attachable

      if attachable.is_a?(ActiveStorage::Blob) && attachable.video?
        link_to attachment.caption || attachable.filename.to_s, post_email_video_url(attachable, post)
      else
        attachment.node
      end
    end
end
