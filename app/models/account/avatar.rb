module Account::Avatar
  extend ActiveSupport::Concern

  ALLOWED_AVATAR_CONTENT_TYPES = %w[ image/jpeg image/png image/gif image/webp ].freeze
  MAX_AVATAR_DIMENSIONS = { width: 4096, height: 4096 }.freeze

  included do
    has_one_attached :avatar, dependent: :purge_later do |attachable|
      attachable.variant :thumb, resize_to_fill: [ 256, 256 ], process: :immediately
    end

    validate :avatar_usable, if: :avatar_attached?
  end

  def avatar_attached?
    avatar.attached?
  end

  # Called after a save that failed: the file sent with it is dropped, so the record reads the logo that is stored.
  def drop_unsaved_avatar
    attachment_changes.delete("avatar")
  end

  def avatar_thumbnail
    avatar.variable? ? avatar.variant(:thumb) : avatar
  end

  def publicly_accessible?
    true
  end

  private
    def avatar_usable
      unless ALLOWED_AVATAR_CONTENT_TYPES.include?(avatar.content_type) && within_avatar_dimensions?
        errors.add :avatar, I18n.t("account_avatar_unusable")
      end
    end

    def within_avatar_dimensions?
      avatar.blob.analyze unless avatar.blob.analyzed?
      width, height = avatar.blob.metadata.values_at(:width, :height)
      width.to_i <= MAX_AVATAR_DIMENSIONS[:width] && height.to_i <= MAX_AVATAR_DIMENSIONS[:height]
    end
end
