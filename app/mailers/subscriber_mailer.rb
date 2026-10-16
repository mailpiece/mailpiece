class SubscriberMailer < ApplicationMailer
  include Mailers::SentBySender

  def confirmation(subscriber, token:)
    @subscriber = subscriber
    @token = token
    @account = subscriber.account

    in_account_locale do
      mail to: @subscriber.email, subject: t("mailers_subscription_confirm_title", name: @account.name)
    end
  end
end
