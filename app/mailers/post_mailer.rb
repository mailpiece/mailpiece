class PostMailer < ApplicationMailer
  include Mailers::SentBySender

  helper PostMailerHelper, PostVideosHelper, TimeHelper

  def issue(post, subscriber, delivery: nil)
    @post = post
    @subscriber = subscriber
    @account = post.account
    @unsubscribe_url = public_subscription_unsubscription_url(subscriber.token)
    @rating_token = delivery.generate_token_for(:rating) if delivery

    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    headers[MailDelivery::TAGS_HEADER] = MailDelivery::ISSUE_TAG

    identify_as delivery if delivery

    in_account_locale do
      mail to: subscriber.email, subject: post.title
    end
  end

  def test_issue(post, email_address)
    @post = post
    @account = post.account

    in_account_locale do
      mail to: email_address, subject: t("mailers_issue_test_subject", title: post.title), template_name: "issue"
    end
  end
end
