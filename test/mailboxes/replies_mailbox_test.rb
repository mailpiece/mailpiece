require "test_helper"

class RepliesMailboxTest < ActionMailbox::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @delivery = post_deliveries(:sent_to_active)
  end

  test "a reply is forwarded to each admin who asked for it" do
    assert_enqueued_emails 2 do
      receive_reply
    end

    perform_enqueued_jobs
    assert_equal [ "leo@example.com", "mia@example.com" ], ActionMailer::Base.deliveries.flat_map(&:to).sort
    forward = ActionMailer::Base.deliveries.first
    assert_equal "Re: Three deadlines in March", forward.subject
    assert_includes forward.body.to_s, %(Reply from ada@example.com to "Three deadlines in March")
    assert_includes forward.body.to_s, "Loved it."
  end

  test "the delivery is named by Delivered-To first, then To" do
    assert_enqueued_emails 2 do
      receive_reply to: "someone@else.example", delivered_to: address
    end

    assert_enqueued_emails 2 do
      receive_reply to: address, delivered_to: nil
    end
  end

  test "a reply with bytes that are not UTF-8 is forwarded all the same" do
    source = "From: ada@example.com\r\nTo: #{address}\r\nSubject: Re\r\nContent-Type: text/plain\r\n\r\nLoved \xFF it.\r\n".b

    assert_enqueued_emails 2 do
      create_inbound_email_from_source(source).route
    end

    assert_includes last_forward.body.to_s, "Loved � it."
  end

  test "a reply to a journey email is forwarded under its subject" do
    @delivery = Journey::Delivery.create!(email: journey_emails(:davids), subscriber: subscribers(:unsubscribed), sent_at: 1.day.ago)

    assert_enqueued_emails 2 do
      receive_reply from: "dan@example.com"
    end

    perform_enqueued_jobs
    assert_equal "Re: Welcome to the bulletin", ActionMailer::Base.deliveries.first.subject
  end

  test "a reply that names no delivery is forwarded to nobody" do
    assert_no_enqueued_emails do
      receive_reply to: "replies+nothing@reply.mailpiece.example", delivered_to: nil
    end
  end

  test "a reply whose From is no address is dropped" do
    [ "not an address", "<ada@example.com" ].each do |from|
      assert_no_enqueued_emails do
        receive_reply from: from
      end
    end
  end

  test "a reply from a reader bounced or let go is not forwarded" do
    @delivery.update!(subscriber: subscribers(:bounced))
    assert_no_enqueued_emails do
      receive_reply from: "cleo@example.com"
    end

    @delivery.update!(subscriber: subscribers(:stopped))
    assert_no_enqueued_emails do
      receive_reply from: "eve@example.com"
    end
  end

  test "a reply from a reader who unsubscribed is forwarded" do
    @delivery = post_deliveries(:sent_to_unsubscribed)

    assert_enqueued_emails 2 do
      receive_reply from: "dan@example.com"
    end
  end

  test "a newsletter cancelled is forwarded nothing" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    assert_no_enqueued_emails do
      receive_reply
    end
  end

  test "a reply from someone other than the subscriber is forwarded under their own address" do
    assert_enqueued_emails 2 do
      receive_reply from: "Someone <else@example.org>"
    end

    assert_includes last_forward.body.to_s, %(Reply from else@example.org to "Three deadlines in March")
  end

  test "a reply is forwarded with no account set, as the routing job runs" do
    inbound_email = create_reply
    Current.clear_all

    assert_enqueued_emails 2 do
      inbound_email.route
    end

    perform_enqueued_jobs
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "a reply goes only to the verified admins who keep the switch on" do
    users(:mia).settings.update!(reply_forwarding: false)
    receive_reply
    assert_equal [ "leo@example.com" ], last_forward.to

    users(:mia).settings.update!(reply_forwarding: true)
    users(:mia).update!(verified_at: nil)
    assert_enqueued_emails 1 do
      receive_reply
    end
  end

  private
    def receive_reply(**options)
      create_reply(**options).tap(&:route)
    end

    def create_reply(from: "Ada <ada@example.com>", to: address, delivered_to: address, body: "Loved it.", **options)
      create_inbound_email_from_mail(from: from, to: to, subject: "Re: #{@delivery.subject}", body: body, **options) do |mail|
        mail.header["Delivered-To"] = delivered_to if delivered_to
      end
    end

    def address
      "replies+#{@delivery.id}@reply.mailpiece.example"
    end

    def last_forward
      perform_enqueued_jobs
      ActionMailer::Base.deliveries.last
    end
end
