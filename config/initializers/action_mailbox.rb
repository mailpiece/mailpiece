module ActionMailboxRelayControllerExtensions
  extend ActiveSupport::Concern

  included do
    around_action :with_account
  end

  private
    def with_account(&)
      # Rails' create reads the body after this, so it is rewound.
      reply = Reply.new(Mail.new(request.body.read)).tap { request.body.rewind }

      if account = reply.account
        Current.with_account(account, &)
      else
        # Mail naming no delivery belongs to no newsletter, so it is answered and not stored.
        head :no_content
      end
    end
end

Rails.application.config.to_prepare do
  ActionMailbox::Ingresses::Relay::InboundEmailsController.include ActionMailboxRelayControllerExtensions
end
