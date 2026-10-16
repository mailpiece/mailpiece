class PostMailer < ApplicationMailer
  include Mailers::SentBySender, Mailers::Offline

  helper PostMailerHelper, PostVideosHelper, TimeHelper

  def issue(post, subscriber, delivery: nil)
    @post = post
    @subscriber = subscriber
    @account = post.account
    @rating_token = delivery.generate_token_for(:rating) if delivery && !offline?

    offer_unsubscription_to subscriber
    headers[MailDelivery::TAGS_HEADER] = MailDelivery::ISSUE_TAG

    identify_as delivery if delivery
    attach_files_of post

    in_account_locale do
      mail to: subscriber.email, subject: post.title
    end
  end

  def test_issue(post, email_address)
    @post = post
    @account = post.account

    attach_files_of post

    in_account_locale do
      mail to: email_address, subject: t("mailers_issue_test_subject", title: post.title), template_name: "issue"
    end
  end
end
