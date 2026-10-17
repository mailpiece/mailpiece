require "test_helper"

class SubscriberMailerTest < ActionMailer::TestCase
  setup do
    @subscriber = subscribers(:unconfirmed)
    @token = @subscriber.send(:generate_confirmation_token)
  end

  test "confirmation goes from the account's sender to the subscriber" do
    email = SubscriberMailer.confirmation(@subscriber, token: @token)

    assert_equal [ @subscriber.email ], email.to
    assert_equal [ "leo@newsletter.example" ], email.from
    assert_match @subscriber.account.name, email.subject
  end

  test "over the relay confirmation leaves with the newsletter's token" do
    send_mail_over :relay, RELAY_TOKEN: "newsletter_token"

    email = SubscriberMailer.confirmation(@subscriber, token: @token)

    assert_kind_of Relay::DeliveryMethod, email.delivery_method
    assert_equal({ url: "https://relay.example/messages", token: "newsletter_token" }, email.delivery_method.settings)
  end

  test "outside production confirmation goes the environment's own way, whatever the newsletter's transport" do
    email = SubscriberMailer.confirmation(@subscriber, token: @token)

    assert_kind_of Mail::TestMailer, email.delivery_method
    assert_not_includes email.delivery_method.settings.values, "stream_token"
  end

  test "in production confirmation with no transport fails when it is sent, and never leaves over the system's SMTP" do
    send_mail_over :nothing

    deliver_as_production do
      email = SubscriberMailer.confirmation(@subscriber, token: @token)
      assert_kind_of MailTransport::Unconfigured, email.delivery_method

      error = assert_raises(MailDelivery::Unavailable) { email.deliver_now }
      assert_match "The newsletter has no transport", error.message
    end

    assert_empty ActionMailer::Base.deliveries
  end

  test "in production a transport nobody knows is no transport" do
    send_mail_over :relay, TRANSPORT: "resend"

    deliver_as_production do
      assert_raises(MailDelivery::Unavailable) { SubscriberMailer.confirmation(@subscriber, token: @token).deliver_now }
    end
  end

  test "in production confirmation over SMTP takes none of the system's SMTP settings" do
    send_mail_over :smtp, SMTP_USERNAME: nil, SMTP_PASSWORD: nil

    deliver_as_production do
      email = SubscriberMailer.confirmation(@subscriber, token: @token)

      assert_kind_of Smtp::DeliveryMethod, email.delivery_method
      assert_equal "smtp.example", email.delivery_method.settings[:address]
      assert_nil email.delivery_method.settings[:user_name]
      assert_nil email.delivery_method.settings[:password]
    end
  end

  test "over SMTP confirmation leaves from the sender with the newsletter's sign-in" do
    send_mail_over :smtp

    email = SubscriberMailer.confirmation(@subscriber, token: @token)

    assert_kind_of Smtp::DeliveryMethod, email.delivery_method
    assert_equal [ "leo@newsletter.example" ], email.from
    assert_equal "mailpiece", email.delivery_method.settings[:user_name]
    assert_not email.delivery_method.settings.key?(:token)
  end

  test "confirmation takes replies at the sender's reply to address" do
    account_senders(:davids).update!(reply_to_address: "editor@newsletter.example")

    assert_equal [ "editor@newsletter.example" ], SubscriberMailer.confirmation(@subscriber, token: @token).reply_to
  end

  test "confirmation has no Reply-To while the sender has no reply to address" do
    assert_nil SubscriberMailer.confirmation(@subscriber, token: @token)["Reply-To"]
  end

  test "confirmation links to the account's confirmation page in both parts, with the token made for it" do
    email = SubscriberMailer.confirmation(@subscriber, token: @token)
    link = "#{@subscriber.account.slug}/subscriptions/#{@token}/confirm"

    assert_includes email.html_part.body.to_s, link
    assert_includes email.text_part.body.to_s, link
  end

  test "confirmation never carries the permanent token, which unsubscribes" do
    email = SubscriberMailer.confirmation(@subscriber, token: @token)

    assert_not_includes email.html_part.body.to_s, @subscriber.token
    assert_not_includes email.text_part.body.to_s, @subscriber.token
  end

  test "the confirmation a request mails carries a link that confirms" do
    subscriber = subscribers(:unsubscribed)

    perform_enqueued_jobs { subscriber.request_confirmation }
    token = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/subscriptions/(\S+)/confirm$}, 1]

    assert subscriber.reload.confirm_using_token(token)
    assert subscriber.active?
  end
end
