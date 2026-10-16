require "test_helper"

class Journey::EmailTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @email = journey_emails(:davids)
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
  end

  test "an email is its account's, and a new one goes with the account's own" do
    assert_equal [ @email, journey_emails(:davids_goodbye) ], accounts(:davids_account).journey_emails.order(:trigger).to_a
    assert_equal [ journey_emails(:other_accounts) ], accounts(:other_account).journey_emails.to_a
    assert_equal accounts(:davids_account), @journey.emails.new.account
  end

  test "summary is squished, cut at the limit and nothing when blank" do
    @email.update!(summary: "  What   to expect ")
    assert_equal "What to expect", @email.summary

    @email.update!(summary: "word " * 100)
    assert_operator @email.summary.length, :<=, Post::SUMMARY_LENGTH

    @email.update!(summary: " ")
    assert_nil @email.summary
  end

  test "an email knows its journey" do
    assert_equal "subscriber_confirmed", @email.journey.trigger
    assert_equal accounts(:davids_account), @email.journey.account
  end

  test "the delay is a whole number of days, none or more" do
    assert_equal 0, @journey.emails.new.delay_days

    [ 0, 1, 30, "7" ].each do |delay|
      @email.delay_days = delay
      assert @email.valid?, "#{delay.inspect} is refused"
    end

    [ -1, 1.5, "soon", nil ].each do |delay|
      @email.delay_days = delay
      assert_not @email.valid?, "#{delay.inspect} is taken"
      assert @email.errors.include?(:delay_days)
    end
  end

  test "a draft while switched off" do
    assert_not @email.draft?

    @email.deactivate

    assert @email.draft?
  end

  test "active holds only the emails switched on" do
    assert_equal [ @email ], Journey::Email.active.to_a
    assert_not_includes Journey::Email.active, journey_emails(:davids_goodbye)

    @email.deactivate

    assert_empty Journey::Email.active
  end

  test "activate and deactivate switch it on and off, any number of times" do
    2.times { @email.deactivate }
    assert_not @email.reload.active?
    assert @email.written?

    2.times { assert @email.activate }
    assert @email.reload.active?
  end

  test "activate refuses an email with no subject or no body, says why and leaves it off" do
    @email.deactivate
    @email.update!(body: "")

    assert_not @email.activate
    assert @email.errors.of_kind?(:body, :blank)
    assert_not @email.active?
    assert_not @email.reload.active?

    @email.update!(subject: "", body: "<p>Hello.</p>")

    assert_not @email.activate
    assert @email.errors.of_kind?(:subject, :blank)
    assert_not @email.reload.active?
  end

  test "edit_from_editor saves what it is given" do
    assert @email.edit_from_editor({ subject: "Glad you came" }, of_draft: false)
    assert_equal "Glad you came", @email.reload.subject

    @email.deactivate
    assert @email.edit_from_editor({ subject: "", body: "" }, of_draft: true)
    assert_not @email.reload.written?
  end

  test "edit_from_editor refuses a blank email while it is switched on" do
    assert_not @email.edit_from_editor({ body: "" }, of_draft: false)
    assert @email.errors.of_kind?(:body, :blank)
    assert @email.reload.written?
  end

  test "edit_from_editor from a draft's editor changes nothing of an email switched on since" do
    assert_nil @email.edit_from_editor({ subject: "An old draft" }, of_draft: true)

    assert_empty @email.errors
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "subject is squished" do
    @email.update!(subject: "  Glad   you came ")

    assert_equal "Glad you came", @email.subject
  end

  test "written with a subject and a body, and valid with neither while it is off" do
    assert @email.written?

    @email.deactivate
    @email.update!(subject: " ", body: "")

    assert_not @email.reload.written?
    assert @email.body_in_email.blank?
  end

  test "switched on, a subject with no body or a body with no subject is refused" do
    @email.assign_attributes(body: "")
    assert_not @email.valid?
    assert @email.errors.of_kind?(:body, :blank)

    @email.reload.assign_attributes(subject: " ")
    assert_not @email.valid?
    assert @email.errors.of_kind?(:subject, :blank)

    @email.active = false
    assert @email.valid?
  end

  test "deliverable and testable while the account sends mail, switched on or not" do
    assert @email.deliverable?
    assert @email.testable?

    @email.deactivate
    assert @email.deliverable?
    assert @email.testable?

    account_senders(:davids).update!(from_address: nil)
    assert_not @email.reload.deliverable?
    assert_not @email.testable?
  end

  test "body_in_email is the body's content" do
    assert_equal "Glad you are here. Reply and say hello.", @email.body_in_email.to_plain_text
  end

  test "body_in_email opens a box kept for the email and drops one kept for the web" do
    @email.update!(body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this.</p></aside><aside data-audience="web"><p>Share this page.</p></aside>))

    assert_equal "Hello.\n\nReply to this.", @email.body_in_email.to_plain_text
    assert_empty @email.body_in_email.fragment.find_all("aside")
  end

  test "it answers what the issue's renderer asks of a post: no page, and no links recorded" do
    assert_not @email.on_the_web?
    assert_empty @email.links
  end

  test "deliver_test_to mails a test to the address" do
    assert_enqueued_email_with JourneyMailer, :test_email, args: [ @email, "editor@example.com" ] do
      assert @email.deliver_test_to("editor@example.com")
    end
  end

  test "deliver_test_to refuses an invalid address" do
    assert_no_enqueued_emails do
      assert_not @email.deliver_test_to("not an address")
    end

    assert_equal [ "Enter a valid email address for the test" ], @email.errors[:base]
  end

  test "deliver_test_to refuses an email not written" do
    @email.deactivate
    @email.update!(subject: "", body: "")

    assert_no_enqueued_emails do
      assert_not @email.deliver_test_to("editor@example.com")
    end

    assert_equal [ "Write the subject and the message before sending a test" ], @email.errors[:base]
  end

  test "deliver_test_to refuses without a complete sender" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_not @email.reload.deliver_test_to("editor@example.com")
    end

    assert_equal [ "Email sending is not set up" ], @email.errors[:sender]
  end

  test "deliver_to writes the subscriber's row and queues it" do
    subscriber = subscribers(:unsubscribed)

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      assert_difference -> { @email.deliveries.count }, +1 do
        @email.deliver_to(subscriber, at: Time.current)
      end
    end

    delivery = @email.deliveries.find_by!(subscriber: subscriber)
    assert delivery.pending?
    assert delivery.deliver_at?
    assert_equal accounts(:davids_account), delivery.account
  end

  test "deliver_to reaches a subscriber once, whatever became of the first row" do
    subscriber = subscribers(:unsubscribed)
    @email.deliver_to(subscriber, at: Time.current)

    [ {}, { sent_at: Time.current }, { refused_at: Time.current }, { claimed_at: 10.minutes.ago } ].each do |state|
      @email.deliveries.find_by!(subscriber: subscriber).update!(sent_at: nil, refused_at: nil, claimed_at: nil, **state)

      assert_no_enqueued_jobs only: Journey::DeliveryJob do
        assert_no_difference -> { Journey::Delivery.count } do
          @email.deliver_to(subscriber, at: Time.current)
        end
      end
    end

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      @email.deliver_to(subscribers(:active), at: Time.current)
    end
  end

  test "deliver_to writes nothing for an email switched off" do
    @email.deactivate

    assert_no_enqueued_jobs do
      assert_no_difference -> { Journey::Delivery.count } do
        assert_nil @email.deliver_to(subscribers(:unsubscribed), at: Time.current)
      end
    end
  end

  test "deliver_to writes the row while the account has no complete sender, which waits for it" do
    account_senders(:davids).update!(from_address: nil)

    assert_difference -> { Journey::Delivery.count }, +1 do
      @email.reload.deliver_to(subscribers(:unsubscribed), at: Time.current)
    end

    assert @email.deliveries.find_by!(subscriber: subscribers(:unsubscribed)).pending?
  end

  test "deliver_to dates the row for the time it is given, and leaves its job waiting until then" do
    freeze_time do
      assert_enqueued_with job: Journey::DeliveryJob, at: 3.days.from_now do
        @email.deliver_to(subscribers(:unsubscribed), at: 3.days.from_now)
      end

      assert_equal 3.days.from_now, @email.deliveries.find_by!(subscriber: subscribers(:unsubscribed)).deliver_at
    end
  end

  test "send_time is the day the person entered plus the delay" do
    @email.update!(delay_days: 3)

    assert_equal Time.utc(2026, 10, 11, 18, 0), @email.send_time(entered_at: Time.utc(2026, 10, 8, 18, 0))
  end

  test "with an hour, send_time is that hour of that day, in the zone it was picked in" do
    Time.use_zone("America/Argentina/Buenos_Aires") { @email.update!(delay_days: 3, send_hour: 9) }
    assert_equal "America/Argentina/Buenos_Aires", @email.time_zone

    assert_equal Time.utc(2026, 10, 11, 12, 0), @email.send_time(entered_at: Time.utc(2026, 10, 8, 18, 0))
  end

  test "send_time of the unsubscribe journey's email is when the person left, whatever its row holds" do
    journey_emails(:davids_goodbye).update_columns delay_days: 4, send_hour: 9, time_zone: "UTC"

    assert_equal Time.utc(2026, 10, 8, 18, 0), journey_emails(:davids_goodbye).send_time(entered_at: Time.utc(2026, 10, 8, 18, 0))
  end

  test "the zone stays the one the hour was first picked in, whoever changes the hour after" do
    Time.use_zone("America/Argentina/Buenos_Aires") { @email.update!(delay_days: 1, send_hour: 9) }

    Time.use_zone("Europe/Madrid") { @email.update!(send_hour: 10) }

    assert_equal 10, @email.reload.send_hour
    assert_equal "America/Argentina/Buenos_Aires", @email.time_zone

    assert_equal Time.utc(2026, 10, 9, 13, 0), @email.send_time(entered_at: Time.utc(2026, 10, 8, 18, 0))
  end

  test "an hour picked again after it went takes the zone of whoever picks it" do
    Time.use_zone("America/Argentina/Buenos_Aires") { @email.update!(send_hour: 9) }
    @email.update!(send_hour: nil)

    Time.use_zone("Europe/Madrid") { @email.update!(send_hour: 10) }

    assert_equal "Europe/Madrid", @email.time_zone
  end

  test "the zone goes when the hour does" do
    Time.use_zone("UTC") { @email.update!(send_hour: 9) }
    @email.update!(send_hour: nil)
    assert_nil @email.time_zone
  end

  test "deleting an email moves the runs waiting on it to the next, and finishes those with none" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 2)
    subscriber = accounts(:davids_account).subscribers.add("reader@example.com")
    @journey.start_for(subscriber)
    run = subscriber.journey_runs.sole

    @email.destroy!

    assert_equal run.created_at + 2.days, second.deliveries.find_by!(subscriber: subscriber).deliver_at
    assert run.reload.in_progress?

    second.destroy!

    assert run.reload.finished?
    assert_empty subscriber.journey_deliveries
  end

  test "deleting an email leaves a run alone that is not waiting on it" do
    second = @journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    @journey.start_for(subscribers(:unconfirmed))

    assert_no_changes -> { subscribers(:unconfirmed).journey_deliveries.sole.attributes } do
      second.destroy!
    end

    assert subscribers(:unconfirmed).journey_runs.sole.in_progress?
  end

  test "its deliveries go with it" do
    assert_difference -> { Journey::Delivery.count }, -1 do
      @email.destroy!
    end
  end

  test "its files are served with no session" do
    blob = ActiveStorage::Blob.create_and_upload! io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg"
    @email.update!(body: "<p>#{ActionText::Attachment.from_attachable(blob).to_html}</p>")

    assert blob.reload.publicly_accessible?
  end
end
