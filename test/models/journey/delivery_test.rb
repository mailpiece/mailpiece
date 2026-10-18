require "test_helper"

class Journey::DeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @email = journey_emails(:davids)
    @goodbye = journey_emails(:davids_goodbye)
    @subscriber = subscribers(:active)
    @email.deliveries.delete_all
    @delivery = @email.deliveries.create!(subscriber: @subscriber)
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @run = journey_runs(:active_confirmed)
    @run.update!(state: :in_progress, ended_at: nil, created_at: 1.hour.ago.change(usec: 0))
  end

  test "a row finds its run by its subscriber and its email's trigger" do
    assert_equal @run, @delivery.run
    assert_equal goodbye_delivery_for(@subscriber).run, @subscriber.journey_runs.find_by!(trigger: "subscriber_unsubscribed")
  end

  test "a row sent writes the next email's row, dated its days from when the person entered, and the run goes on" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 3)
    third = @journey.emails.create!(subject: "And another", body: "<p>Last.</p>", active: true, delay_days: 5)

    freeze_time do
      assert_enqueued_with job: Journey::DeliveryJob, at: @run.created_at + 3.days do
        @delivery.deliver_now
      end

      assert_equal @run.created_at + 3.days, second.deliveries.sole.deliver_at
    end

    assert_equal @subscriber, second.deliveries.sole.subscriber
    assert_empty third.deliveries
    assert @run.reload.in_progress?
  end

  test "a row sent twice over writes the next row once" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 1)

    third = @journey.emails.create!(subject: "And another", body: "<p>Last.</p>", active: true, delay_days: 2)
    other_worker = Journey::Delivery.find(@delivery.id)

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      @delivery.deliver_now
      other_worker.send(:record_sent, ActionMailer::Base.deliveries.last)
    end

    assert_equal 1, second.deliveries.count
    assert_empty third.deliveries
    assert @run.reload.in_progress?
  end

  test "a row dropped twice over moves the run once" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 1)
    third = @journey.emails.create!(subject: "And another", body: "<p>Last.</p>", active: true, delay_days: 2)
    other_worker = Journey::Delivery.find(@delivery.id)
    @email.deactivate

    @delivery.skip
    other_worker.skip

    assert_equal 1, second.deliveries.count
    assert_empty third.deliveries
    assert @run.reload.in_progress?
  end

  test "the last row sent finishes the run" do
    freeze_time do
      @delivery.deliver_now

      assert @run.reload.finished?
      assert_equal Time.current, @run.ended_at
    end
  end

  test "an email added, switched on or given another delay after the start is what the run comes to in its turn" do
    draft = @journey.emails.create!(subject: "Was a draft", body: "<p>Soon.</p>", delay_days: 1)
    added = @journey.emails.create!(subject: "Added later", body: "<p>New.</p>", active: true)
    draft.activate
    draft.update!(delay_days: 5)

    freeze_time do
      @delivery.deliver_now
      assert_equal [ added ], @subscriber.journey_deliveries.pending.map(&:email)

      added.deliveries.sole.deliver_now
      assert_equal @run.created_at + 5.days, draft.deliveries.sole.deliver_at
    end

    assert @run.reload.in_progress?
  end

  test "the run never goes back to an email placed before the one it has reached" do
    earlier = @journey.emails.create!(subject: "Given an earlier day", body: "<p>Early.</p>", active: true, delay_days: 1)
    @email.update!(delay_days: 2)

    @delivery.deliver_now

    assert_empty earlier.deliveries
    assert @run.reload.finished?
  end

  test "the stamp does not stand when the run cannot move on" do
    @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    Journey::Email.any_instance.stubs(:deliver_to).raises(ActiveRecord::StatementInvalid)

    assert_raises(ActiveRecord::StatementInvalid) { @delivery.deliver_now }

    assert_not @delivery.reload.sent_at?
    assert @run.reload.in_progress?
  end

  test "a row whose email was switched off is dropped, and the run goes on to the next" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 2)
    @email.deactivate

    freeze_time do
      assert_no_emails { Journey::Delivery.find(@delivery.id).deliver_now }

      assert_equal @run.created_at + 2.days, second.deliveries.sole.deliver_at
    end

    assert_not Journey::Delivery.exists?(@delivery.id)
    assert @run.reload.in_progress?
  end

  test "a row whose email was switched off finishes the run when nothing comes after it" do
    @email.deactivate

    Journey::Delivery.find(@delivery.id).deliver_now

    assert @run.reload.finished?
  end

  test "a row for a person who left is dropped, and ends the run saying so" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    @subscriber.unsubscribe

    assert_no_emails { @delivery.deliver_now }

    assert_not Journey::Delivery.exists?(@delivery.id)
    assert_empty second.deliveries
    assert @run.reload.left?
    assert @run.ended_at?
  end

  test "a refused row ends the run as refused, and the next is never written" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    Mail::TestMailer.any_instance.stubs(:deliver!).raises(MailDelivery::Refused)

    assert_raises(MailDelivery::Refused) { @delivery.deliver_now }

    assert @delivery.reload.refused_at?
    assert_empty second.deliveries
    assert @run.reload.refused?
  end

  test "a row that fails for now leaves the run in progress" do
    Mail::TestMailer.any_instance.stubs(:deliver!).raises(MailDelivery::Throttled)

    assert_raises(MailDelivery::Throttled) { @delivery.deliver_now }

    assert @delivery.reload.pending?
    assert @run.reload.in_progress?
  end

  test "over SMTP a claim left standing leaves the run in progress, with nothing written after it" do
    send_mail_over :smtp
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    @delivery.update!(claimed_at: 10.minutes.ago)

    assert_no_emails { @delivery.deliver_now }

    assert_empty second.deliveries
    assert @run.reload.in_progress?
  end

  test "over the relay a message never answered claims nothing, and the job retries it under the same key" do
    send_mail_over :relay
    stub_dns_resolution PUBLIC_IP
    stub_request(:post, "https://relay.example/messages").with(headers: { "Idempotency-Key" => @delivery.id }).to_raise(Net::ReadTimeout)

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      Journey::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.pending?
    assert_nil @delivery.claimed_at
    assert @run.reload.in_progress?
  end

  test "a refusal that comes for a row no longer waiting refuses nothing and ends nothing" do
    @delivery.update!(sent_at: Time.current)

    @delivery.send(:refuse)

    assert_not @delivery.reload.refused_at?
    assert @run.reload.in_progress?
  end

  test "the unsubscribe journey's run finishes after its one email" do
    @goodbye.activate
    @subscriber.unsubscribe
    run = @subscriber.journey_runs.find_by!(trigger: "subscriber_unsubscribed")

    assert_emails(1) { @goodbye.deliveries.sole.deliver_now }

    assert run.reload.finished?
  end

  test "the unsubscribe journey's run ends as left once the person is back on the list" do
    @goodbye.activate
    @subscriber.unsubscribe
    @subscriber.update!(unsubscribed_at: nil)

    assert_no_emails { @goodbye.deliveries.sole.deliver_now }

    assert @subscriber.journey_runs.find_by!(trigger: "subscriber_unsubscribed").left?
  end

  test "a row takes its email's account" do
    assert_equal accounts(:davids_account), @delivery.account
  end

  test "a subscriber holds one row per email" do
    assert_raises(ActiveRecord::RecordNotUnique) { @email.deliveries.create!(subscriber: @subscriber) }
  end

  test "deliver_now sends the email once" do
    assert_emails 1 do
      2.times { @delivery.deliver_now }
    end

    assert @delivery.sent_at?
    assert_equal [ @subscriber.email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Welcome to the bulletin", ActionMailer::Base.deliveries.last.subject
    assert_equal @delivery.id, ActionMailer::Base.deliveries.last["Idempotency-Key"].value
    assert_equal "#{@delivery.id}@newsletter.example", ActionMailer::Base.deliveries.last.message_id
  end

  test "deliver_now sends nothing for an email switched off since, and drops the row" do
    @email.deactivate

    assert_no_emails do
      assert_difference -> { Journey::Delivery.count }, -1 do
        Journey::Delivery.find(@delivery.id).deliver_now
      end
    end
  end

  test "deliver_now sends nothing to a subscriber who left since, and drops the row" do
    @subscriber.unsubscribe

    assert_no_emails do
      assert_difference -> { Journey::Delivery.count }, -1 do
        @delivery.deliver_now
      end
    end
  end

  test "deliver_now of the unsubscribe journey's email reaches a person who is unsubscribed" do
    @goodbye.activate
    delivery = goodbye_delivery_for(subscribers(:unsubscribed))

    assert_emails 1 do
      2.times { delivery.deliver_now }
    end

    assert delivery.sent_at?
    assert_equal [ subscribers(:unsubscribed).email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Sorry to see you go", ActionMailer::Base.deliveries.last.subject
    assert_nil ActionMailer::Base.deliveries.last["List-Unsubscribe"]
  end

  test "deliver_now of the unsubscribe journey's email sends nothing to anyone who is not unsubscribed, and drops the row" do
    @goodbye.activate

    %i[ active unconfirmed bounced stopped ].each do |name|
      delivery = goodbye_delivery_for(subscribers(name))

      assert_no_emails do
        assert_difference -> { Journey::Delivery.count }, -1 do
          delivery.deliver_now
        end
      end
    end
  end

  test "deliver_now of the unsubscribe journey's email sends nothing once the person is back on the list" do
    @goodbye.activate
    @subscriber.unsubscribe
    delivery = @goodbye.deliveries.sole
    @subscriber.update!(unsubscribed_at: nil)

    assert_no_emails do
      assert_difference -> { Journey::Delivery.count }, -1 do
        delivery.deliver_now
      end
    end
  end

  test "deliver_now of the unsubscribe journey's email sends nothing once it is switched off" do
    @goodbye.activate
    delivery = goodbye_delivery_for(subscribers(:unsubscribed))
    @goodbye.deactivate

    assert_no_emails do
      assert_difference -> { Journey::Delivery.count }, -1 do
        Journey::Delivery.find(delivery.id).deliver_now
      end
    end
  end

  test "deliver_now sends nothing while the sender is incomplete, and the row waits for it" do
    account_senders(:davids).update!(from_address: "")

    assert_no_emails { Journey::Delivery.find(@delivery.id).deliver_now }
    assert @delivery.reload.pending?
  end

  test "deliver_later leaves the row to its job" do
    assert_enqueued_with job: Journey::DeliveryJob, args: [ @delivery ] do
      @delivery.deliver_later
    end

    assert @delivery.reload.deliver_at?
  end

  test "the job retries a throttled delivery" do
    Journey::Delivery.any_instance.stubs(:deliver_now).raises(MailDelivery::Throttled)

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      Journey::DeliveryJob.perform_now(@delivery)
    end
  end

  test "the job gives up on a refused delivery" do
    Mail::TestMailer.any_instance.stubs(:deliver!).raises(MailDelivery::Refused)

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      Journey::DeliveryJob.perform_now(@delivery)
    end

    assert @delivery.reload.refused_at?
  end

  test "deliver_stalled_later leaves the sweep to its job" do
    assert_enqueued_with job: Journey::Delivery::DeliverStalledJob do
      Journey::Delivery.deliver_stalled_later
    end
  end

  test "the sweep queues a stalled row again with a new turn" do
    @delivery.update!(deliver_at: 3.hours.ago)

    assert_enqueued_with job: Journey::DeliveryJob, args: [ @delivery ] do
      Journey::Delivery::DeliverStalledJob.perform_now
    end

    assert @delivery.reload.deliver_at.after?(1.minute.ago)
  end

  test "the sweep takes its turns from now, and not from behind a row dated days ahead" do
    later = @email.deliveries.create!(subscriber: subscribers(:unconfirmed), deliver_at: 5.days.from_now)
    @delivery.update!(deliver_at: 3.hours.ago)

    freeze_time do
      assert_no_changes -> { later.reload.deliver_at } do
        Journey::Delivery.deliver_stalled_now
      end

      assert_equal Time.current, @delivery.reload.deliver_at
    end
  end

  test "the sweep leaves a row alone until its day has come and gone" do
    @delivery.update!(deliver_at: 2.days.from_now)

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      Journey::Delivery.deliver_stalled_now
    end

    travel 2.days + SentOnce::STALLED_AFTER + 1.minute

    assert_enqueued_with job: Journey::DeliveryJob, args: [ @delivery ] do
      Journey::Delivery.deliver_stalled_now
    end
  end

  private
    def goodbye_delivery_for(subscriber)
      @goodbye.journey.runs.create!(subscriber: subscriber)
      @goodbye.deliveries.create!(subscriber: subscriber)
    end
end
