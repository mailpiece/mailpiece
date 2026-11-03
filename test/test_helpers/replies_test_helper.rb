module RepliesTestHelper
  extend ActiveSupport::Concern

  included do
    setup do
      @replies_domain_before = Account.replies_domain
    end

    teardown do
      Account.replies_domain = @replies_domain_before
    end
  end

  def receive_replies
    Account.replies_domain = "reply.mailpiece.example"
  end
end
