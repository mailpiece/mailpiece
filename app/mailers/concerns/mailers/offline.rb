# An offline install reaches its mail server and no reader reaches it, so a newsletter's mail carries its own
# pictures and files, and nothing in it leads back to the app.
module Mailers::Offline
  extend ActiveSupport::Concern

  PICTURE = Attachments::VARIANTS[:large].merge(resize_to_limit: [ PostMailerHelper::EMAIL_IMAGE_WIDTH, nil ])

  included do
    helper_method :offline?, :attached_picture_url
  end

  private
    def offline?
      Rails.configuration.x.offline
    end

    def offer_unsubscription_to(subscriber)
      if offline?
        headers["List-Unsubscribe"] = "<mailto:#{@account.sender.reply_address}?subject=unsubscribe>"
      else
        @unsubscribe_url = public_subscription_unsubscription_url(subscriber.token)

        headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
        headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
      end
    end

    # Rails takes a message's inline files before its body is drawn, so they are attached from the text first.
    # A blob takes its account from Current, and a variant or a preview made here is a new one.
    def attach_files_of(readable)
      if offline? && content = readable.body_in_email
        Current.with_account(@account) do
          content.attachables.grep(ActiveStorage::Blob).uniq.each { attach_file it }
          Post::Video.all_in(content.fragment).filter_map { readable.video_thumbnail(it) }.uniq.each { attach_file it }
        end
      end
    end

    def attach_file(blob)
      if blob.image?
        attach_picture blob, (blob.variable? ? blob.variant(PICTURE).processed : blob)
      elsif blob.video?
        attach_picture blob, blob.preview(PICTURE).processed if blob.previewable?
      else
        attachments[blob.filename.to_s] = blob.download
      end
    end

    # Named for the blob, since files pasted into a post often share a name.
    def attach_picture(blob, picture)
      name = "#{blob.id}#{picture.filename.extension_with_delimiter}"

      attachments.inline[name] = { mime_type: picture.content_type, content: picture.download }
      attached_picture_urls[blob.id] = attachments[name].url
    end

    def attached_picture_url(blob)
      attached_picture_urls[blob.id]
    end

    def attached_picture_urls
      @attached_picture_urls ||= {}
    end
end
