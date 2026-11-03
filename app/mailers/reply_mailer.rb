class ReplyMailer < ApplicationMailer
  def forward(inbound_email, user)
    @reply = Reply.new(inbound_email.mail)
    @account = user.account

    @account.in_locale do
      mail to: user.identity.email_address, from: email_address_with_name(system_address, @account.name),
        reply_to: email_address_with_name(@reply.from_address, @reply.from_name),
        subject: t("mailers_reply_subject", subject: @reply.subject)
    end
  end

  private
    def system_address
      Mail::Address.new(self.class.default[:from]).address
    end
end
