# Never serve a blob inline with a media type a browser or Turbo will execute as
# markup. Turbo's frame renderer treats a whole family of declared types as HTML
# (FetchResponse#isHTML is /^(?:text\/([^\s;,]+\b)?html|application\/xhtml\+xml)\b/,
# so "text/x-html" or "text/html;charset=utf-8" count), and Content-Disposition
# does not stop Turbo's fetch. This mirrors that matcher case-insensitively and
# adds the scriptable SVG/XML types, so every such blob is forced to
# application/octet-stream.
ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPE = %r{
  \A(?:
      text/(?:[^\s;,]+\b)?html
    | application/xhtml\+xml
    | image/svg\+xml
    | application/xml
    | text/xml
  )\b
}xi

ActiveSupport.on_load :active_storage_blob do
  def accessible_to?(user)
    attached = attachments.includes(:record).to_a

    if attached.any?
      attached.any? { |attachment| attachment.accessible_to?(user) }
    else
      unattached_accessible_to?(user)
    end
  end

  def publicly_accessible?
    attachments.includes(:record).any? { |attachment| attachment.publicly_accessible? }
  end

  private
    # An unattached blob is only meant to be viewable in the brief window
    # between direct upload and attachment, by a user of the blob's own account.
    def unattached_accessible_to?(user)
      user.present? && account_id == user.account_id
    end

    def forcibly_serve_as_binary?
      super || dangerous_inline_media_type?
    end

    def dangerous_inline_media_type?
      declared = content_type.to_s.strip
      # A legitimate media type is ASCII. Forcing every non-ASCII one to binary also
      # keeps Ruby's Unicode \b congruent with Turbo's ASCII \b ("text/htmlé").
      !declared.ascii_only? || ActiveStorage::DANGEROUS_INLINE_MEDIA_TYPE.match?(declared)
    end
end

ActiveSupport.on_load :active_storage_attachment do
  def accessible_to?(user)
    record.try(:accessible_to?, user)
  end

  def publicly_accessible?
    record.try(:publicly_accessible?)
  end
end

Rails.application.config.to_prepare do
  module ActiveStorage::Authorize
    extend ActiveSupport::Concern

    include Authentication

    included do
      # Ensure require_authentication runs after set_blob.
      skip_before_action :require_authentication
      before_action :require_authentication, :ensure_accessible, unless: :publicly_accessible_blob?
    end

    private
      def bearer_token_authenticatable_request?
        true
      end

      def publicly_accessible_blob?
        @blob.publicly_accessible?
      end

      def ensure_accessible
        unless @blob.accessible_to?(Current.user)
          head :forbidden
        end
      end

      def http_cache_forever(public: false, **options, &block)
        super(public: public && publicly_accessible_blob?, **options, &block)
      end
  end

  ActiveStorage::Blobs::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Blobs::ProxyController.include ActiveStorage::Authorize

  # set_representation is a before_action on Representations::BaseController that runs
  # @blob.representation(...).processed, the ffmpeg/mutool/libvips parser. Registered on
  # the parent, it would precede the authorization callbacks appended above, so it is
  # re-appended to run after require_authentication and ensure_accessible.
  [ ActiveStorage::Representations::RedirectController, ActiveStorage::Representations::ProxyController ].each do |controller|
    controller.include ActiveStorage::Authorize
    controller.skip_before_action :set_representation
    controller.before_action :set_representation
  end
end
