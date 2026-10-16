require "test_helper"

class JourneyMailerTest < ActionMailer::TestCase
  setup do
    @email = journey_emails(:davids)
    @goodbye = journey_emails(:davids_goodbye)
    @subscriber = subscribers(:active)
    @unsubscribe_path = "#{@email.account.slug}/subscriptions/#{@subscriber.token}/unsubscribe"
  end

  test "email opens with its summary, hidden, so an inbox shows it beside the subject" do
    assert_no_match "display: none", JourneyMailer.email(@email, @subscriber).html_part.body.to_s

    @email.update!(summary: "What to expect")

    assert_match %r{<div style="display: none;[^"]*">What to expect</div>}, JourneyMailer.email(@email, @subscriber).html_part.body.to_s
  end

  test "email goes from the account's sender to the subscriber, tagged as an issue" do
    email = JourneyMailer.email(@email, @subscriber)

    assert_equal [ @subscriber.email ], email.to
    assert_equal [ "leo@newsletter.example" ], email.from
    assert_equal "Welcome to the bulletin", email.subject
    assert_equal "issue", email["X-Tags"].value
    assert_nil email["Idempotency-Key"]
  end

  test "email of a delivery carries its id as the idempotency key and the same Message-ID every time it is built" do
    delivery = journey_deliveries(:sent_to_active)
    first, second = 2.times.map { JourneyMailer.email(@email, @subscriber, delivery: delivery).deliver_now }

    assert_equal delivery.id, JourneyMailer.email(@email, @subscriber, delivery: delivery)["Idempotency-Key"].value
    assert_equal "#{delivery.id}@newsletter.example", first.message_id
    assert_equal first.message_id, second.message_id
  end

  test "email has the name of the newsletter and the body in both parts, and no heading" do
    email = JourneyMailer.email(@email, @subscriber)

    assert_includes Nokogiri::HTML5.fragment(email.html_part.body.to_s).text, @email.account.name
    assert_includes email.html_part.body.to_s, "Glad you are here. Reply and say hello."
    assert_includes email.text_part.body.to_s, "Glad you are here. Reply and say hello."
    assert_empty Nokogiri::HTML5.fragment(email.html_part.body.to_s).css("h1")
  end

  test "email carries the unsubscribe link in both parts and in the one-click header" do
    email = JourneyMailer.email(@email, @subscriber)

    assert_includes email.html_part.body.to_s, @unsubscribe_path
    assert_includes email.text_part.body.to_s, @unsubscribe_path
    assert_match @unsubscribe_path, email["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", email["List-Unsubscribe-Post"].value
  end

  test "email links to its own account with no account set" do
    Current.without_account do
      assert_includes JourneyMailer.email(@email, @subscriber).text_part.body.to_s, @unsubscribe_path
    end
  end

  test "email keeps the markup a mail client shows, drops the rest and leaves its links as written" do
    @email.update!(body: %(<h2>Hello</h2><p style="color: red" onclick="x()">Start <a href="https://example.org/start">here</a></p>))

    email = JourneyMailer.email(@email, @subscriber)
    html = email.html_part.body.to_s

    assert_includes html, %(href="https://example.org/start")
    assert_includes html, "margin: 0 0 16px;"
    assert_includes html, %(<h2 style="font-family: Georgia, 'Times New Roman', serif;)
    assert_not_includes html, "color: red"
    assert_not_includes html, "onclick"
    assert_includes email.text_part.body.to_s, "[here](https://example.org/start)"
  end

  test "email loads an image from an address in its own account, and links an attached video to its file" do
    image = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    video = ActiveStorage::Blob.create_and_upload! io: StringIO.new("video"), filename: "clip.mp4", content_type: "video/mp4", identify: false
    @email.update!(body: "<p>#{ActionText::Attachment.from_attachable(image).to_html}</p>#{ActionText::Attachment.from_attachable(video).to_html}")

    Current.without_account do
      html = Nokogiri::HTML5.fragment(JourneyMailer.email(@email, @subscriber).html_part.body.to_s)

      assert_includes html.at_css("figure > img")["src"], "#{@email.account.slug}/rails/active_storage/blobs/proxy/"
      assert_includes html.at_css("figure > a")["href"], "/rails/active_storage/blobs/proxy/"
    end
  end

  test "offline, email and test_email carry an uploaded picture inline, with no account set, and email offers unsubscribing by a reply to the from address" do
    image = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    @email.update!(body: "<p>#{ActionText::Attachment.from_attachable(image).to_html}</p>")

    while_offline do
      Current.without_account do
        [ JourneyMailer.email(@email, @subscriber), JourneyMailer.test_email(@email, "editor@example.com") ].each do |email|
          assert_equal email.attachments.sole.url, Nokogiri::HTML5.fragment(email.html_part.body.to_s).at_css("figure > img")["src"]
          assert_not_includes email.html_part.body.to_s, "http://example.com"
          assert_not_includes email.text_part.body.to_s, "http://example.com"
        end

        email = JourneyMailer.email(@email, @subscriber)

        assert_equal "<mailto:leo@newsletter.example?subject=unsubscribe>", email["List-Unsubscribe"].value
        assert_nil email["List-Unsubscribe-Post"]
        assert_includes CGI.unescapeHTML(email.html_part.body.to_s), %(To unsubscribe, reply to this email with "unsubscribe".)
        assert_includes email.text_part.body.to_s, %(To unsubscribe, reply to this email with "unsubscribe".)
      end
    end
  end

  test "email takes replies at the sender's reply to address" do
    account_senders(:davids).update!(reply_to_address: "editor@newsletter.example")

    assert_equal [ "editor@newsletter.example" ], JourneyMailer.email(@email, @subscriber).reply_to
    assert_equal [ "editor@newsletter.example" ], JourneyMailer.test_email(@email, "editor@example.com").reply_to
  end

  test "over the relay email leaves with the newsletter's token" do
    send_mail_over :relay, RELAY_TOKEN: "newsletter_token"

    [ JourneyMailer.email(@email, @subscriber), JourneyMailer.test_email(@email, "editor@example.com") ].each do |email|
      assert_kind_of Relay::DeliveryMethod, email.delivery_method
      assert_equal({ url: "https://relay.example/messages", token: "newsletter_token" }, email.delivery_method.settings)
    end
  end

  test "email is written in the account's language" do
    @email.account.update!(locale: "es")

    assert_includes JourneyMailer.email(@email, @subscriber).text_part.body.to_s, "Darme de baja"
    assert_equal "[Prueba] Welcome to the bulletin", JourneyMailer.test_email(@email, "editor@example.com").subject
  end

  test "test_email is marked in the subject and carries no unsubscribe link" do
    email = JourneyMailer.test_email(@email, "editor@example.com")

    assert_equal [ "editor@example.com" ], email.to
    assert_equal "[Test] Welcome to the bulletin", email.subject
    assert_nil email["List-Unsubscribe"]
    assert_nil email["X-Tags"]
    assert_includes email.html_part.body.to_s, "Glad you are here. Reply and say hello."
    assert_includes email.html_part.body.to_s, "This is a test copy of an email of a journey."
    assert_includes email.text_part.body.to_s, "This is a test copy of an email of a journey."
    assert_not_includes email.html_part.body.to_s, "/unsubscribe"
    assert_not_includes email.text_part.body.to_s, "/unsubscribe"
  end

  test "email of the unsubscribe journey says the person is no longer subscribed, and offers no way out" do
    email = JourneyMailer.email(@goodbye, subscribers(:unsubscribed))

    assert_equal [ subscribers(:unsubscribed).email ], email.to
    assert_equal [ "leo@newsletter.example" ], email.from
    assert_equal "Sorry to see you go", email.subject
    assert_nil email["List-Unsubscribe"]
    assert_nil email["List-Unsubscribe-Post"]
    assert_nil email["X-Tags"]

    [ Nokogiri::HTML5.fragment(email.html_part.body.to_s).text, email.text_part.body.to_s ].each do |part|
      assert_includes part, "You will get no more issues. Come back any time."
      assert_includes part, "You are no longer subscribed to #{@goodbye.account.name}."
      assert_not_includes part, "You are receiving this because"
    end

    assert_not_includes email.html_part.body.to_s, "/unsubscribe"
    assert_not_includes email.text_part.body.to_s, "/unsubscribe"
  end

  test "email of the unsubscribe journey still carries its delivery's idempotency key and Message-ID" do
    delivery = @goodbye.deliveries.create!(subscriber: subscribers(:unsubscribed))
    email = JourneyMailer.email(@goodbye, subscribers(:unsubscribed), delivery: delivery).deliver_now

    assert_equal delivery.id, email["Idempotency-Key"].value
    assert_equal "#{delivery.id}@newsletter.example", email.message_id
  end

  test "email of the unsubscribe journey says so in the account's language" do
    @goodbye.account.update!(locale: "es")

    assert_includes JourneyMailer.email(@goodbye, subscribers(:unsubscribed)).text_part.body.to_s, "Ya no tenés una suscripción a #{@goodbye.account.name}."
  end

  test "test_email of the unsubscribe journey is a test copy like any other" do
    email = JourneyMailer.test_email(@goodbye, "editor@example.com")

    assert_equal "[Test] Sorry to see you go", email.subject
    assert_includes email.text_part.body.to_s, "This is a test copy of an email of a journey."
    assert_not_includes email.text_part.body.to_s, "no longer subscribed"
  end
end
