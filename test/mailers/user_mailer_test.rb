require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "system mail goes the environment's own way" do
    assert_kind_of Mail::TestMailer, email.delivery_method
  end

  test "system mail goes the environment's own way whatever the newsletter sends with" do
    [ :relay, :smtp ].each do |transport|
      send_mail_over transport

      assert_kind_of Mail::TestMailer, email.delivery_method
    end
  end

  test "in production system mail leaves over Action Mailer's SMTP, and a newsletter's mail over its own transport" do
    send_mail_over :relay

    deliver_as_production do
      assert_instance_of Mail::SMTP, email.delivery_method
      assert_equal "system.example", email.delivery_method.settings[:address]
      assert_equal "system_password", email.delivery_method.settings[:password]
      assert_not email.delivery_method.settings.key?(:token)

      confirmation = SubscriberMailer.confirmation(subscribers(:unconfirmed), token: "token")
      assert_kind_of Relay::DeliveryMethod, confirmation.delivery_method
      assert_equal({ url: "https://relay.example/messages", token: "stream_token" }, confirmation.delivery_method.settings)
    end
  end

  test "in production system mail asks nothing of the newsletter's transport" do
    [ :smtp, :nothing ].each do |transport|
      send_mail_over transport

      deliver_as_production do
        assert_instance_of Mail::SMTP, email.delivery_method
        assert_equal "system.example", email.delivery_method.settings[:address]
      end
    end
  end

  private
    def email
      UserMailer.email_change_confirmation(email_address: "new@example.com", token: "token", user: users(:leo))
    end
end
