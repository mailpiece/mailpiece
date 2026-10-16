require "test_helper"

class Post::DeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  RELAY_URL = "https://relay.example/messages"

  setup do
    @post = Current.account.posts.create!(title: "News", body: "<p>Hello</p>", published_at: Time.current, sent_at: Time.current)
    @delivery = @post.deliveries.create!(subscriber: subscribers(:active))
  end

  test "deliver_now sends the issue once" do
    assert_emails 1 do
      2.times { @delivery.deliver_now }
    end

    assert @delivery.sent_at?
    assert_equal @delivery.id, ActionMailer::Base.deliveries.last["Idempotency-Key"].value
    assert_equal "#{@delivery.id}@newsletter.example", ActionMailer::Base.deliveries.last.message_id
  end

  test "over SMTP the row keeps the Message-ID the message left with" do
    send_mail_over :smtp
    smtp_session.expects(:sendmail).with { |message, *| message.include?("Message-ID: <#{@delivery.id}@newsletter.example>") }

    @delivery.deliver_now

    assert_equal "#{@delivery.id}@newsletter.example", @delivery.reload.message_id
  end

  test "deliver_now of an issue sets nothing off: no journey's run is written or moved" do
    assert_no_changes -> { Journey::Run.order(:id).map(&:attributes) } do
      assert_no_difference -> { Journey::Delivery.count } do
        @delivery.deliver_now
      end
    end

    assert_equal SentOnce, Post::Delivery.instance_method(:was_sent).owner
    assert_equal SentOnce, Post::Delivery.instance_method(:drop).owner
  end

  test "deliver_now leaves the row pending when the message does not go out" do
    PostMailer.any_instance.stubs(:mail).raises(MailDelivery::Throttled)

    assert_raises(MailDelivery::Throttled) { @delivery.deliver_now }
    assert @delivery.reload.pending?
  end

  test "deliver_now sends nothing to a subscriber who left since, and drops the row" do
    subscribers(:active).unsubscribe

    assert_no_emails do
      assert_difference -> { @post.reload.deliveries_count }, -1 do
        @delivery.deliver_now
      end
    end
  end

  test "deliver_now sends nothing while the sender is incomplete, and the row waits for it" do
    account_senders(:davids).update!(from_address: "")

    assert_no_emails { Post::Delivery.find(@delivery.id).deliver_now }
    assert @delivery.reload.pending?

    account_senders(:davids).update!(from_address: "leo@newsletter.example")

    assert_emails(1) { Post::Delivery.find(@delivery.id).deliver_now }
    assert @delivery.reload.sent_at?
  end

  test "the job retries a throttled delivery" do
    Post::Delivery.any_instance.stubs(:deliver_now).raises(MailDelivery::Throttled)

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end
  end

  test "deliver_now marks a refused delivery, whoever asked for it" do
    Mail::TestMailer.any_instance.stubs(:deliver!).raises(MailDelivery::Refused)

    assert_raises(MailDelivery::Refused) { @delivery.deliver_now }

    assert @delivery.reload.refused_at?
    assert_not @delivery.pending?
  end

  test "the job gives up on a refused delivery" do
    Mail::TestMailer.any_instance.stubs(:deliver!).raises(MailDelivery::Refused)

    assert_no_enqueued_jobs only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.refused_at?
    assert_not @delivery.pending?
  end

  test "over the relay a row is never claimed, and a failed send is swept as before" do
    send_mail_over :relay
    stub_request(:post, RELAY_URL).to_return({ status: 503 }, { status: 201, body: { message_id: "<abc@newsletter.example>" }.to_json })

    assert_raises(MailDelivery::Unavailable) { @delivery.deliver_now }
    assert @delivery.reload.pending?
    assert_nil @delivery.claimed_at
    @delivery.update!(deliver_at: 3.hours.ago)
    assert_includes Post::Delivery.stalled, @delivery

    @delivery.deliver_now
    assert @delivery.reload.sent_at?
    assert_nil @delivery.claimed_at
    assert_equal "abc@newsletter.example", @delivery.message_id
  end

  test "over the relay a message posted and never answered is retried with the same key" do
    send_mail_over :relay
    stub_request(:post, RELAY_URL).with(headers: { "Idempotency-Key" => @delivery.id }).to_raise(Net::ReadTimeout)

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end
    assert @delivery.reload.pending?
    assert_nil @delivery.claimed_at

    stub_request(:post, RELAY_URL).with(headers: { "Idempotency-Key" => @delivery.id }).to_return(status: 201, body: "{}")
    @delivery.deliver_now
    assert @delivery.reload.sent_at?
  end

  test "over the relay two workers holding the same row both post it under one key, for the relay to send once" do
    send_mail_over :relay
    stub = stub_request(:post, RELAY_URL).with(headers: { "Idempotency-Key" => @delivery.id }).to_return(status: 201, body: "{}")
    other = Post::Delivery.find(@delivery.id)

    [ @delivery, other ].each(&:deliver_now)

    assert_requested stub, times: 2
    assert @delivery.reload.sent_at?
    assert_nil @delivery.claimed_at
  end

  test "over the relay a message taken with an answer that cannot be read is recorded as sent" do
    send_mail_over :relay
    stub_request(:post, RELAY_URL).to_return(status: 201, body: "")

    @delivery.deliver_now

    assert @delivery.reload.sent_at?
  end

  test "over SMTP of two workers holding the same row only one sends" do
    send_mail_over :smtp
    smtp_session.expects(:sendmail).once
    other = Post::Delivery.find(@delivery.id)

    [ @delivery, other ].each(&:deliver_now)

    assert @delivery.reload.sent_at?
    assert @delivery.claimed_at?
  end

  test "over SMTP a claim left standing is passed by a second deliver_now and by the sweep" do
    send_mail_over :smtp
    smtp_session.expects(:sendmail).never
    @delivery.update!(claimed_at: 1.minute.ago, deliver_at: 3.hours.ago)
    @post.deliveries.create!(subscriber: subscribers(:unconfirmed), claimed_at: 1.minute.ago, created_at: 20.minutes.ago)

    @delivery.deliver_now

    assert_empty Post::Delivery.stalled
    assert_no_enqueued_jobs only: Post::DeliveryJob do
      Post::Delivery.deliver_stalled_now
    end
    assert_not @delivery.reload.sent_at?
  end

  test "over SMTP a crash after the claim leaves it standing" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(RuntimeError, "the process died")

    assert_raises(RuntimeError) { @delivery.deliver_now }

    assert @delivery.reload.claimed_at?
    assert_not @delivery.pending?
    assert_not @delivery.sent_at?
  end

  test "over SMTP a bug in the sending is not a refusal, and its claim stands like any crash's" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(ArgumentError, "wrong number of arguments")

    assert_raises(ArgumentError) { Post::DeliveryJob.perform_now(@delivery) }

    assert_not @delivery.reload.refused_at?
    assert @delivery.claimed_at?
  end

  test "over SMTP a message handed over and never answered leaves the claim standing, and the job does not retry" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(Net::ReadTimeout)

    assert_no_enqueued_jobs only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.claimed_at?
    assert_not @delivery.sent_at?
    assert_not @delivery.refused_at?
  end

  test "over SMTP a post that cannot be built claims nothing" do
    send_mail_over :smtp
    PostMailer.any_instance.stubs(:mail).raises(RuntimeError)

    assert_raises(RuntimeError) { @delivery.deliver_now }
    assert @delivery.reload.pending?
  end

  test "over SMTP the job retries a throttled delivery, its claim released" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(Net::SMTPServerBusy, "451 4.3.2 Try again later")

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.pending?
  end

  test "over SMTP the job retries when the server is out of reach or turns the install down, with no claim left" do
    send_mail_over :smtp

    [ Errno::ECONNREFUSED, Net::SMTPAuthenticationError.new("535 5.7.8 Bad credentials") ].each do |failure|
      Net::SMTP.any_instance.stubs(:start).raises(failure)

      assert_enqueued_jobs 1, only: Post::DeliveryJob do
        Post::DeliveryJob.perform_now(@delivery)
      end

      assert @delivery.reload.pending?
    end
  end

  test "over SMTP the job marks a refused delivery and gives up" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(Net::SMTPFatalError, "550 5.1.1 No such user")

    assert_no_enqueued_jobs only: Post::DeliveryJob do
      Post::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.refused_at?
    assert_nil @delivery.claimed_at
  end

  test "over SMTP a released claim is sent on the next turn" do
    send_mail_over :smtp
    smtp_session.stubs(:sendmail).raises(Net::SMTPServerBusy, "451 4.3.2 Try again later").then.returns(true)

    assert_raises(MailDelivery::Throttled) { @delivery.deliver_now }
    @delivery.deliver_now

    assert @delivery.reload.sent_at?
  end

  test "a standing claim reads as unverified once its send cannot still be under way" do
    @delivery.update!(claimed_at: 1.minute.ago)
    assert_equal "pending", @delivery.state
    assert_equal({ sent: 0, refused: 0, unverified: 0 }, Post.where(id: @post).delivery_progress[@post.id])

    @delivery.update!(claimed_at: 10.minutes.ago)
    assert_equal "unverified", @delivery.state
    assert_equal({ sent: 0, refused: 0, unverified: 1 }, Post.where(id: @post).delivery_progress[@post.id])

    @delivery.update!(sent_at: Time.current)
    assert_equal "sent", @delivery.state
    assert_equal({ sent: 1, refused: 0, unverified: 0 }, Post.where(id: @post).delivery_progress[@post.id])
  end

  test "deliver_later gives each pending row its own turn, behind what any newsletter has waiting" do
    waiting = posts(:other_accounts).deliveries.create!(subscriber: subscribers(:other_accounts), deliver_at: 1.minute.from_now)
    second = @post.deliveries.create!(subscriber: subscribers(:unconfirmed))

    assert_enqueued_jobs 2, only: Post::DeliveryJob do
      @post.deliveries.deliver_later
    end

    turns = [ @delivery, second ].map { |delivery| delivery.reload.deliver_at }
    assert turns.all? { |turn| turn > waiting.deliver_at }
    assert_equal 2, turns.uniq.size
  end

  test "stalled is what waited past its turn, or never got one" do
    @delivery.update!(deliver_at: 3.hours.ago)
    unscheduled = @post.deliveries.create!(subscriber: subscribers(:unconfirmed), created_at: 20.minutes.ago)
    @post.deliveries.create!(subscriber: subscribers(:stopped), deliver_at: 1.minute.ago)
    @post.deliveries.create!(subscriber: subscribers(:bounced))

    assert_equal [ @delivery, unscheduled ].to_set, Post::Delivery.stalled.to_set
  end

  test "stalled leaves a cancelled account alone" do
    @delivery.update!(deliver_at: 3.hours.ago)
    @post.deliveries.create!(subscriber: subscribers(:unconfirmed), created_at: 20.minutes.ago)
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    assert_empty Post::Delivery.stalled
  end

  test "deliver_stalled_later leaves the sweep to its job" do
    assert_enqueued_with job: Post::Delivery::DeliverStalledJob do
      Post::Delivery.deliver_stalled_later
    end
  end

  test "deliver_stalled_now queues a stalled row again with a new turn" do
    @delivery.update!(deliver_at: 3.hours.ago)

    assert_enqueued_with job: Post::DeliveryJob, args: [ @delivery ] do
      Post::Delivery.deliver_stalled_now
    end

    assert @delivery.reload.deliver_at.after?(1.minute.ago)
  end

  private
    # Stands in for the server: the session opens and the test says what becomes of the message.
    def smtp_session
      mock("smtp").tap do |smtp|
        smtp.stubs(:finish)
        Net::SMTP.any_instance.stubs(:start).returns(smtp)
      end
    end
end
