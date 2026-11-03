class Reply
  PATTERN = /\+([^+@\s]+)@/

  delegate :account, :subscriber, :subject, to: :delivery, allow_nil: true

  class << self
    def address_for(delivery)
      "replies+#{delivery.id}@#{Account.replies_domain}"
    end
  end

  def initialize(mail)
    @mail = mail
  end

  def delivery
    if token
      @delivery ||= Post::Delivery.find_by(id: token) || Journey::Delivery.find_by(id: token)
    end
  end

  def from_address
    mail.from_address&.address
  end

  def from_name
    mail.from_address&.display_name
  end

  def text
    body_text.to_s.strip
  end

  # A message that is itself one file has no parts.
  def attachments_count
    mail.attachment? ? 1 : mail.attachments.size
  end

  private
    attr_reader :mail

    def token
      @token ||= (header(:delivered_to) || mail.to&.first).to_s[PATTERN, 1]
    end

    def header(name)
      Array(mail.header[name]).first&.value
    end

    def body_text
      if mail.multipart?
        scrub(mail.text_part&.decoded)
      elsif mail.mime_type.nil? || mail.mime_type == "text/plain"
        scrub(mail.decoded)
      end
    end

    def scrub(string)
      if string
        string.force_encoding(Encoding::UTF_8).scrub
      end
    end
end
