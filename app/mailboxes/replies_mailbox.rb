class RepliesMailbox < ApplicationMailbox
  around_processing :with_account

  def process
    if forwardable?
      recipients.each { |user| ReplyMailer.forward(inbound_email, user).deliver_later }
    end
  end

  private
    def forwardable?
      reply.delivery.present? && reply.from_address.present? &&
        reply.account.active? && reply.subscriber.reachable?
    end

    def reply
      @reply ||= Reply.new(mail)
    end

    def recipients
      reply.account.users.notified_of(:reply_forwarding)
    end

    # The routing job is not an ApplicationJob, so AccountTenanted does not set the account for it.
    def with_account(&)
      Current.with_account(inbound_email.account, &)
    end
end
