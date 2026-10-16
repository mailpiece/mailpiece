# A link of a mailed issue. The email points at our redirect, so where it leads can be corrected after it went out.
class Post::Link < ApplicationRecord
  CODE_LENGTH = 8
  TEXT_LENGTH = 255
  WEB_ADDRESS = %r{\Ahttps?://\S+\z}i

  belongs_to :account, default: -> { post.account }
  belongs_to :post

  normalizes :text, with: ->(text) { text.squish.truncate(TEXT_LENGTH) }

  validates :url, format: { with: WEB_ADDRESS, message: ->(*) { I18n.t("posts_links_invalid_url") } }

  before_create :assign_code

  # Never corrected, and the text mailed no longer has it: the writer took the link out or changed it in the post.
  def stale?
    url == original_url && !post.email_links.key?(original_url)
  end

  private
    def assign_code
      self.code = SecureRandom.base36(CODE_LENGTH) while code.blank? || account.post_links.exists?(code: code)
    end
end
