module Post::Sluggable
  extend ActiveSupport::Concern

  FALLBACK_SLUG = "post"
  CODE_LENGTH = 8

  included do
    before_create :assign_code
  end

  def slug
    title.to_s.parameterize.presence || FALLBACK_SLUG
  end

  # The public address. The code finds the post; the slug is there to be read and follows the title.
  def public_param
    "#{slug}-#{code}"
  end

  private
    def assign_code
      self.code = SecureRandom.hex(CODE_LENGTH / 2) while code.blank? || account.posts.exists?(code: code)
    end
end
