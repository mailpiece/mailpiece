class ReplyMailerPreview < ActionMailer::Preview
  InboundEmail = Struct.new(:mail)

  def forward
    ReplyMailer.forward(posted, admin)
  end

  def forward_from_someone_else
    ReplyMailer.forward(posted(from: "Someone Else <else@example.org>", attachments: 2), admin)
  end

  private
    def delivery
      @delivery ||= Post::Delivery.first
    end

    def admin
      delivery.account.users.admin.first
    end

    def posted(from: delivery.subscriber.email, attachments: 0)
      mail = Mail.new(from: from, to: "replies+#{delivery.id}@reply.example", subject: "Re: #{delivery.subject}")
      mail.text_part = "Thanks for this one.\n\nWhen is the next workshop?"
      mail.header["Delivered-To"] = mail.to.first
      attachments.times { |number| mail.add_file(filename: "photo-#{number}.jpg", content: "") }

      InboundEmail.new(mail)
    end
end
