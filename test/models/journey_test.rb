require "test_helper"

class JourneyTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:davids_account)
    @confirmed = @account.journey_triggered_by("subscriber_confirmed")
    @unsubscribed = @account.journey_triggered_by("subscriber_unsubscribed")
  end

  test "an account has one journey for each trigger, in the order they are listed" do
    assert_equal Journey::TRIGGERS, @account.journeys.map(&:trigger)
    assert_equal [ @account ], @account.journeys.map(&:account).uniq
  end

  test "its trigger is what its address ends with" do
    assert_equal "subscriber_confirmed", @confirmed.to_param
  end

  test "its label is written in the language asked for" do
    assert_equal "When someone subscribes", @confirmed.label
    assert_equal "When someone unsubscribes", @unsubscribed.label

    I18n.with_locale(:es) do
      assert_equal "Cuando alguien se suscribe", @confirmed.label
      assert_equal "Cuando alguien se da de baja", @unsubscribed.label
    end
  end

  test "its emails are the account's own for its trigger, by their day, then their hour, then as they were written" do
    later = @confirmed.emails.create!(subject: "Two days in", delay_days: 2)
    morning = @confirmed.emails.create!(subject: "The first morning", send_hour: 9)
    sooner = @confirmed.emails.create!(subject: "A day in", delay_days: 1)
    last = @confirmed.emails.create!(subject: "Two days in, again", delay_days: 2)

    assert_equal [ journey_emails(:davids), morning, sooner, later, last ], @confirmed.emails.to_a
    assert_equal [ journey_emails(:davids_goodbye) ], @unsubscribed.emails.to_a
    assert_equal [ journey_emails(:other_accounts) ], accounts(:other_account).journey_triggered_by("subscriber_confirmed").emails.to_a
  end

  test "a new email of a journey is written for its trigger" do
    assert_equal "subscriber_confirmed", @confirmed.emails.new.trigger
    assert_equal "subscriber_unsubscribed", @unsubscribed.emails.new.trigger
    assert_equal @account, @unsubscribed.emails.new.account
  end

  test "the confirmation's journey takes any number of emails, each with a delay" do
    3.times { @confirmed.emails.create! }

    assert @confirmed.addable?
    assert @confirmed.delayed?
    assert_not @confirmed.single?
  end

  test "the unsubscribe journey takes one email, with no delay" do
    assert_not @unsubscribed.addable?
    assert_not @unsubscribed.delayed?
    assert @unsubscribed.single?

    journey_emails(:davids_goodbye).destroy!

    assert @unsubscribed.addable?
  end

  test "recipients are the active for the confirmation's journey and the unsubscribed for the other" do
    assert_equal [ subscribers(:active) ], @confirmed.recipients.to_a
    assert_equal [ subscribers(:unsubscribed) ], @unsubscribed.recipients.to_a
  end

  test "start_for writes the run and the row of the first email alone, dated by its own delay" do
    journey_emails(:davids).update!(delay_days: 1)
    second = @confirmed.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 2)

    freeze_time do
      assert_enqueued_jobs 1, only: Journey::DeliveryJob do
        assert_difference -> { @confirmed.runs.count }, +1 do
          @confirmed.start_for(subscribers(:unconfirmed))
        end
      end

      delivery = subscribers(:unconfirmed).journey_deliveries.sole
      assert_equal journey_emails(:davids), delivery.email
      assert_equal 1.day.from_now, delivery.deliver_at
      assert_enqueued_with job: Journey::DeliveryJob, args: [ delivery ], at: 1.day.from_now
    end

    run = subscribers(:unconfirmed).journey_runs.sole
    assert_equal "subscriber_confirmed", run.trigger
    assert_equal @account, run.account
    assert run.in_progress?
    assert_empty second.deliveries
  end

  test "start_for begins with the first email switched on, in the order the emails are in" do
    second = @confirmed.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 2)
    journey_emails(:davids).update!(delay_days: 3)
    @confirmed.start_for(subscribers(:unconfirmed))
    assert_equal second, subscribers(:unconfirmed).journey_deliveries.sole.email

    second.deactivate
    @confirmed.start_for(subscribers(:unsubscribed))
    assert_equal journey_emails(:davids), subscribers(:unsubscribed).journey_deliveries.sole.email
  end

  test "start_for takes a person once, ever: a second start writes nothing and moves nothing" do
    @confirmed.start_for(subscribers(:unconfirmed))
    delivery = subscribers(:unconfirmed).journey_deliveries.sole

    travel 1.day

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert_no_difference [ -> { Journey::Delivery.count }, -> { Journey::Run.count } ] do
        assert_no_changes -> { delivery.reload.deliver_at } do
          @confirmed.start_for(subscribers(:unconfirmed))
        end
      end
    end
  end

  test "start_for takes nobody whose run has ended, however it ended" do
    assert_no_difference [ -> { Journey::Delivery.count }, -> { Journey::Run.count } ] do
      @confirmed.start_for(subscribers(:active))
    end

    @confirmed.start_for(subscribers(:unconfirmed))
    subscribers(:unconfirmed).journey_runs.sole.end_as :left
    Journey::Delivery.where(subscriber: subscribers(:unconfirmed)).delete_all

    assert_no_difference -> { Journey::Delivery.count } do
      @confirmed.start_for(subscribers(:unconfirmed))
    end
  end

  test "start_for writes no run while no email is switched on, so a journey written later still takes the person" do
    journey_emails(:davids).deactivate

    assert_no_difference [ -> { Journey::Run.count }, -> { Journey::Delivery.count } ] do
      assert_nil @confirmed.start_for(subscribers(:unconfirmed))
    end

    journey_emails(:davids).activate

    assert_difference -> { Journey::Run.count }, +1 do
      @confirmed.start_for(subscribers(:unconfirmed))
    end
  end

  test "start_for writes nothing while the account has no complete sender" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_jobs do
      assert_no_difference [ -> { Journey::Delivery.count }, -> { Journey::Run.count } ] do
        @account.reload.journey_triggered_by("subscriber_confirmed").start_for(subscribers(:unconfirmed))
      end
    end
  end

  test "start_for of the unsubscribe journey sends its email at once, whatever delay its row holds" do
    journey_emails(:davids_goodbye).activate
    journey_emails(:davids_goodbye).update_column :delay_days, 4

    freeze_time do
      @unsubscribed.start_for(subscribers(:unsubscribed))

      assert_equal Time.current, journey_emails(:davids_goodbye).deliveries.sole.deliver_at
    end

    assert_equal "subscriber_unsubscribed", subscribers(:unsubscribed).journey_runs.sole.trigger
  end

  test "next_email_for is the first email switched on after the one given that the person has no row for" do
    second = @confirmed.emails.create!(subject: "Second", body: "<p>Two.</p>", active: true, delay_days: 1)
    draft = @confirmed.emails.create!(subject: "Not yet", delay_days: 2)
    fourth = @confirmed.emails.create!(subject: "Fourth", body: "<p>Four.</p>", active: true, delay_days: 3)
    subscriber = subscribers(:unconfirmed)

    assert_equal journey_emails(:davids), @confirmed.next_email_for(subscriber)
    assert_equal second, @confirmed.next_email_for(subscriber, after: journey_emails(:davids))
    assert_equal fourth, @confirmed.next_email_for(subscriber, after: second)
    assert_equal fourth, @confirmed.next_email_for(subscriber, after: draft)
    assert_nil @confirmed.next_email_for(subscriber, after: fourth)

    fourth.deliveries.create!(subscriber: subscriber)
    assert_nil @confirmed.next_email_for(subscriber, after: second)
  end

  test "next_email_for never goes back to an email placed before the one given" do
    earlier = @confirmed.emails.create!(subject: "Earlier", body: "<p>One.</p>", active: true, delay_days: 1)
    journey_emails(:davids).update!(delay_days: 2)

    assert_equal earlier, @confirmed.next_email_for(subscribers(:unconfirmed))
    assert_nil @confirmed.next_email_for(subscribers(:unconfirmed), after: journey_emails(:davids))
  end

  test "next_email_for of the unsubscribe journey is its one email and nothing after it, were a second ever written" do
    journey_emails(:davids_goodbye).activate
    @account.journey_emails.create!(trigger: "subscriber_unsubscribed", subject: "And another thing", body: "<p>Wait.</p>", active: true)

    assert_equal journey_emails(:davids_goodbye), @unsubscribed.next_email_for(subscribers(:unsubscribed))
    assert_nil @unsubscribed.next_email_for(subscribers(:unsubscribed), after: journey_emails(:davids_goodbye))
  end
end
