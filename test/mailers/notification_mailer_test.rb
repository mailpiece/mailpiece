require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  test "new_subscriber names the address and links to the subscriber and to the switch" do
    assert_equal [ identities(:mia).email_address ], email.to
    assert_equal "New subscriber: ben@example.com", email.subject

    assert_includes email.html_part.body.to_s, "ben@example.com subscribed to Leo&#39;s Account."
    assert_includes email.text_part.body.to_s, "ben@example.com subscribed to Leo's Account."

    [ email.html_part, email.text_part ].each do |part|
      assert_includes part.body.to_s, "http://example.com/1234567/subscribers/#{subscribers(:unconfirmed).id}"
      assert_includes part.body.to_s, "http://example.com/1234567/notifications/settings"
    end
  end

  test "new_subscriber is written in the account's language" do
    accounts(:davids_account).update!(locale: "es")

    assert_equal "Nueva suscripción: ben@example.com", email.subject
    assert_includes email.text_part.body.to_s, "ben@example.com se suscribió a Leo's Account."
  end

  test "new_subscriber is system mail, whatever the newsletter sends with" do
    send_mail_over :relay

    assert_kind_of Mail::TestMailer, email.delivery_method

    deliver_as_production do
      assert_instance_of Mail::SMTP, email.delivery_method
    end
  end

  private
    def email
      NotificationMailer.new_subscriber(users(:mia), subscribers(:unconfirmed))
    end
end
