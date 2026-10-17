module Mailers::SentBySender
  extend ActiveSupport::Concern

  included do
    default from: -> { @account.sender.from },
      reply_to: -> { @account.sender.reply_to },
      delivery_method: -> { mail_transport.delivery_method },
      delivery_method_options: -> { mail_transport.settings }
  end

  private
    def mail_transport
      MailTransport.newsletter(@account)
    end

    # A delivery's own message is the same however often it is built: the row's id is its idempotency key
    # where the transport takes one, and its Message-ID everywhere, since some mailbox providers drop a
    # second message that carries a Message-ID they have seen.
    def identify_as(delivery)
      headers[MailDelivery::IDEMPOTENCY_KEY_HEADER] = delivery.id
      headers["Message-ID"] = "<#{delivery.id}@#{@account.sender.domain}>"
    end

    # A newsletter's mail may be sent from a sweep, with no account set for the process. Its links are a
    # reader's, so they lead to the newsletter's domain when it has one.
    def default_url_options
      super.merge(@account.reader_url_options)
    end

    # A newsletter's mail is written in the newsletter's language, whoever asked for it and from wherever:
    # a request, a job or a sweep. The subject and the templates are both read inside the block.
    def in_account_locale(&)
      @account.in_locale(&)
    end
end
