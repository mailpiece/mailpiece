class NotificationMailer < ApplicationMailer
  def new_subscriber(user, subscriber)
    @subscriber = subscriber
    @account = user.account

    @account.in_locale do
      mail to: user.identity.email_address, subject: t("mailers_new_subscriber_subject", email: subscriber.email)
    end
  end
end
