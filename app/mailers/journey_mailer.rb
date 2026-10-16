class JourneyMailer < ApplicationMailer
  include Mailers::SentBySender, Mailers::Offline

  helper PostMailerHelper, PostVideosHelper

  def email(email, subscriber, delivery: nil)
    @email = email
    @subscriber = subscriber
    @account = email.account

    if email.journey.to_unsubscribed?
      @unsubscribed = true
    else
      offer_unsubscription
    end

    identify_as delivery if delivery
    attach_files_of email

    in_account_locale do
      mail to: subscriber.email, subject: email.subject
    end
  end

  def test_email(email, email_address)
    @email = email
    @account = email.account

    attach_files_of email

    in_account_locale do
      mail to: email_address, subject: t("mailers_issue_test_subject", title: email.subject), template_name: "email"
    end
  end

  private
    # Tagged as an issue: it goes to an active subscriber, so an address the provider suppresses over it has bounced.
    # The email of the unsubscribe journey goes to someone who left, and says nothing about them.
    def offer_unsubscription
      offer_unsubscription_to @subscriber
      headers[MailDelivery::TAGS_HEADER] = MailDelivery::ISSUE_TAG
    end
end
