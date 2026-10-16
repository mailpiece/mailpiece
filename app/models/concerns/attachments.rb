module Attachments
  extend ActiveSupport::Concern

  # Patched into ActionText::RichText in config/initializers/action_text.rb. Processed
  # immediately so a variant is never generated from a read replica.
  VARIANTS = {
    # vipsthumbnail's intent setting filters gif-incompatible intents and flattens the
    # animation; an invalid `n` skips that filtering and keeps every frame. Only `n` is
    # accepted as an override; the full `intent` name does not work.
    small: { loader: { n: -1 }, resize_to_limit: [ 800, 600 ] },
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }.freeze

  def attachments
    rich_text_record&.embeds || []
  end

  def has_attachments?
    attachments.any?
  end

  def remote_images
    @remote_images ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteImage) || []
  end

  def has_remote_images?
    remote_images.any?
  end

  def remote_videos
    @remote_videos ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteVideo) || []
  end

  def has_remote_videos?
    remote_videos.any?
  end

  private
    def rich_text_record
      @rich_text_record ||= begin
        association = self.class.reflect_on_all_associations(:has_one).find { it.klass == ActionText::RichText }
        public_send(association.name)
      end
    end
end
