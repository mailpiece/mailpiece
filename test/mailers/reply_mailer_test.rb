require "test_helper"
require "action_mailbox/test_helper"

class ReplyMailerTest < ActionMailer::TestCase
  include ActionMailbox::TestHelper

  setup do
    @delivery = post_deliveries(:sent_to_active)
    @user = users(:mia)
  end

  test "forward goes from the system's address in the newsletter's name, answered at the reader's" do
    email = forward

    assert_equal [ "mia@example.com" ], email.to
    assert_equal [ "support@mailpiece.dev" ], email.from
    assert_equal "Leo's Account", email[:from].display_names.first
    assert_equal [ "ada@example.com" ], email.reply_to
    assert_equal "Ada Lovelace", email[:reply_to].display_names.first
    assert_nil email.in_reply_to
    assert_equal "Re: Three deadlines in March", email.subject
    assert_equal "text/plain", email.mime_type
    assert_includes email.body.to_s, %(Reply from ada@example.com to "Three deadlines in March")
    assert_includes email.body.to_s, "Loved it."
    assert_includes email.body.to_s, "http://example.com/1234567/subscribers/#{subscribers(:active).id}"
  end

  test "forward from an address with no name is answered at the bare address" do
    assert_equal "ada@example.com", forward(from: "ada@example.com")[:reply_to].value
  end

  test "forward says how to turn these emails off" do
    assert_includes forward.body.to_s, "You can turn these emails off in your notification settings: http://example.com/1234567/notifications/settings"
  end

  test "forward from someone other than the subscriber is answered at their address" do
    assert_equal [ "else@example.org" ], forward(from: "Someone <else@example.org>").reply_to
  end

  test "forward counts the attachments it leaves behind" do
    assert_includes forward(attachments: 2).body.to_s, "(2 attachments not forwarded)"
    assert_not_includes forward.body.to_s, "not forwarded"
  end

  test "forward of a reply that is only a photo has no text and counts the photo" do
    email = forward(body: "\xFF\xD8\xFFphoto".b, content_type: 'image/jpeg; name="photo.jpg"')

    assert_includes email.body.to_s, "(1 attachment not forwarded)"
    assert_not_includes email.body.to_s, "photo"
  end

  test "forward is written in the account's language" do
    accounts(:davids_account).update!(locale: "es")

    assert_includes forward.body.to_s, %(Respuesta de ada@example.com a "Three deadlines in March")
  end

  test "forward is system mail, whatever the newsletter sends with" do
    send_mail_over :relay

    assert_kind_of Mail::TestMailer, forward.delivery_method

    deliver_as_production do
      assert_instance_of Mail::SMTP, forward.delivery_method
    end
  end

  private
    def forward(from: "Ada Lovelace <ada@example.com>", body: "Loved it.", attachments: 0, **options)
      inbound_email = create_inbound_email_from_mail(from: from, to: "replies+#{@delivery.id}@reply.mailpiece.example", subject: "Re", body: body, **options) do |mail|
        attachments.times { |number| mail.add_file(filename: "photo-#{number}.jpg", content: "x") }
      end

      ReplyMailer.forward(inbound_email, @user)
    end
end
