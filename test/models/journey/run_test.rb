require "test_helper"

class Journey::RunTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:davids_account)
    @journey = @account.journey_triggered_by("subscriber_confirmed")
    @subscriber = @account.subscribers.add("reader@example.com")
    @run = @journey.runs.create!(subscriber: @subscriber)
  end

  test "a run is its subscriber's account's, knows its journey and starts in progress" do
    assert_equal @account, Journey::Run.create!(subscriber: subscribers(:unconfirmed), trigger: "subscriber_unsubscribed").account
    assert_equal "subscriber_confirmed", @run.journey.trigger
    assert_equal @account, @run.journey.account
    assert @run.in_progress?
    assert_nil @run.ended_at
  end

  test "a person has one run per trigger, ever" do
    assert_raises(ActiveRecord::RecordNotUnique) { @journey.runs.create!(subscriber: @subscriber) }

    assert_nothing_raised { @account.journey_triggered_by("subscriber_unsubscribed").runs.create!(subscriber: @subscriber) }
  end

  test "end_as ends a run once, and what came first stands" do
    freeze_time do
      @run.end_as :finished
      assert_equal Time.current, @run.ended_at
    end

    travel 1.day

    assert_no_changes -> { @run.reload.attributes } do
      @run.end_as :left
    end

    assert @run.finished?
  end

  test "end_as says how, in a word the run knows" do
    @run.end_as :refused

    assert @run.reload.refused?
    assert @run.ended_at?
    assert_raises(ArgumentError) { @journey.runs.new.end_as(:bored) }
  end

  test "advance with nothing sent yet writes the row of the first email" do
    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      @run.advance
    end

    assert_equal [ journey_emails(:davids) ], @subscriber.journey_deliveries.map(&:email)
    assert @run.reload.in_progress?
  end

  test "advance writes the row of the next email, dated its delay from when the person entered" do
    @run.update!(created_at: 1.day.ago.change(usec: 0))
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 4)

    assert_enqueued_with job: Journey::DeliveryJob, at: @run.created_at + 4.days do
      @run.advance past: journey_emails(:davids)
    end

    assert_equal @run.created_at + 4.days, second.deliveries.find_by!(subscriber: @subscriber).deliver_at
    assert @run.reload.in_progress?
  end

  test "advance dates an email with an hour for that hour of its day" do
    @run.update!(created_at: Time.utc(2026, 10, 8, 18, 0))
    second = Time.use_zone("UTC") { @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 3, send_hour: 9) }

    travel_to Time.utc(2026, 10, 8, 19, 0) do
      @run.advance past: journey_emails(:davids)

      assert_equal Time.utc(2026, 10, 11, 9, 0), second.deliveries.find_by!(subscriber: @subscriber).deliver_at
    end
  end

  test "advance sends now an email whose day or hour has gone by" do
    @run.update!(created_at: Time.utc(2026, 10, 1, 18, 0))
    late = @journey.emails.create!(subject: "Switched on late", body: "<p>Late.</p>", active: true, delay_days: 2)
    gone = Time.use_zone("UTC") { @journey.emails.create!(subject: "Its hour went", body: "<p>Gone.</p>", active: true, delay_days: 7, send_hour: 9) }

    travel_to Time.utc(2026, 10, 8, 18, 0) do
      @run.advance past: journey_emails(:davids)
      assert_equal Time.current, late.deliveries.find_by!(subscriber: @subscriber).deliver_at

      @run.advance past: late
      assert_equal Time.current, gone.deliveries.find_by!(subscriber: @subscriber).deliver_at
    end
  end

  test "advance passes over an email switched off" do
    @journey.emails.create!(subject: "Not yet", delay_days: 1)
    third = @journey.emails.create!(subject: "And another", body: "<p>Last.</p>", active: true, delay_days: 2)

    @run.advance past: journey_emails(:davids)

    assert_equal [ third ], @subscriber.journey_deliveries.map(&:email)
  end

  test "advance finishes the run when no email is left" do
    @run.advance past: journey_emails(:davids)

    assert @run.reload.finished?
    assert @run.ended_at?
    assert_empty @subscriber.journey_deliveries
  end

  test "advance does nothing to a run that has ended, though this copy of it has not heard" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    Journey::Run.find(@run.id).end_as :left

    assert_no_difference -> { Journey::Delivery.count } do
      @run.advance past: journey_emails(:davids)
    end

    assert_empty second.deliveries
    assert @run.reload.left?
  end
end
