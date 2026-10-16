require "test_helper"

class SubscriberTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @subscribers = accounts(:davids_account).subscribers
  end

  test "active is confirmed and neither unsubscribed, bounced nor stopped" do
    assert_equal [ subscribers(:active) ], @subscribers.active.to_a
  end

  test "status reads bounced, then stopped, then unsubscribed, then confirmed" do
    assert_equal :active, subscribers(:active).status
    assert_equal :unconfirmed, subscribers(:unconfirmed).status
    assert_equal :unsubscribed, subscribers(:unsubscribed).status
    assert_equal :deactivated, subscribers(:stopped).status
    assert_equal :bounced, subscribers(:bounced).status

    subscribers(:unsubscribed).update!(deactivated_at: Time.current)
    assert_equal :deactivated, subscribers(:unsubscribed).status

    subscribers(:unsubscribed).update!(bounced_at: Time.current)
    assert_equal :bounced, subscribers(:unsubscribed).status
  end

  test "email is normalized" do
    assert_equal "new@example.com", @subscribers.create!(email: "  New@Example.COM ").email
  end

  test "subscribe adds an unconfirmed row and mails one confirmation" do
    assert_enqueued_emails 1 do
      assert_difference -> { @subscribers.unconfirmed.count }, +1 do
        @subscribers.subscribe("new@example.com")
      end
    end
  end

  test "subscribe keeps where the row came from, and a later subscribe never writes over it" do
    subscriber = @subscribers.subscribe("new@example.com", source_post: posts(:sent), referrer: "https://example.com/blog")

    assert_equal posts(:sent), subscriber.source_post
    assert_equal "example.com", subscriber.referrer_host

    @subscribers.subscribe("new@example.com", source_post: posts(:unlisted), referrer: "https://other.example/")

    assert_equal posts(:sent), subscriber.reload.source_post
    assert_equal "https://example.com/blog", subscriber.referrer
  end

  test "referrer is cut to what its column holds" do
    assert_equal 255, Subscriber.new(referrer: "https://example.com/#{"a" * 300}").referrer.length
  end

  test "add records no source" do
    subscriber = @subscribers.add("new@example.com")

    assert_nil subscriber.source_post
    assert_nil subscriber.referrer
  end

  test "referrer_host is nothing for a referrer that is not an address" do
    assert_nil Subscriber.new(referrer: "not a url ^").referrer_host
    assert_nil Subscriber.new.referrer_host
  end

  test "subscribe mails an address once and no more until it confirms" do
    assert_enqueued_emails 1 do
      2.times { @subscribers.subscribe("new@example.com") }

      3.times do
        travel 1.minute
        @subscribers.subscribe("new@example.com")
      end
    end
  end

  test "subscribe drops an address, with no row, once the newsletter mailed its confirmations for the hour" do
    Subscriber::CONFIRMATIONS_PER_HOUR.times do |position|
      @subscribers.create!(email: "flood#{position}@example.com", confirmation_sent_at: Time.current)
    end

    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        @subscribers.subscribe("new@example.com")
      end
    end

    travel 61.minutes

    assert_enqueued_emails 1 do
      @subscribers.subscribe("new@example.com")
    end
  end

  test "subscribe mails again an address that confirmed, unsubscribed and subscribed again within the hour" do
    @subscribers.subscribe("new@example.com")
    subscriber = @subscribers.find_by!(email: "new@example.com")
    subscriber.confirm_using_token confirmation_token_for(subscriber)
    subscriber.unsubscribe

    assert_enqueued_emails 1 do
      @subscribers.subscribe("new@example.com")
    end
  end

  test "subscribe mails nothing to a confirmed or stopped address" do
    assert_no_enqueued_emails do
      @subscribers.subscribe(subscribers(:active).email)
      @subscribers.subscribe(subscribers(:stopped).email)
    end

    assert subscribers(:active).reload.active?
    assert subscribers(:stopped).reload.deactivated?
  end

  test "subscribe mails a bounced address and leaves it bounced" do
    assert_enqueued_emails 1 do
      assert_no_difference -> { Subscriber.count } do
        @subscribers.subscribe(subscribers(:bounced).email)
      end
    end

    assert subscribers(:bounced).reload.bounced?
  end

  test "subscribe mails a bounced address once and no more until it confirms" do
    assert_enqueued_emails 1 do
      2.times { @subscribers.subscribe(subscribers(:bounced).email) }

      3.times do
        travel 1.minute
        @subscribers.subscribe(subscribers(:bounced).email)
      end
    end
  end

  test "subscribe mails nothing to a bounced address an admin had stopped" do
    subscribers(:stopped).bounce

    assert_no_enqueued_emails do
      @subscribers.subscribe(subscribers(:stopped).email)
    end
  end

  test "subscribe mails an unsubscribed address and leaves it unsubscribed" do
    assert_enqueued_emails 1 do
      assert_no_difference -> { Subscriber.count } do
        @subscribers.subscribe(subscribers(:unsubscribed).email)
      end
    end

    assert subscribers(:unsubscribed).reload.unsubscribed?
  end

  test "subscribe drops a Gmail address scattered with dots, with no row and no mail" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        assert_not @subscribers.subscribe("j.o.h.n.smith@gmail.com").persisted?
        @subscribers.subscribe("J.o.h.n@GoogleMail.com")
      end
    end
  end

  test "subscribe takes an ordinary Gmail address and a plus address" do
    assert_enqueued_emails 3 do
      assert_difference -> { @subscribers.unconfirmed.count }, +3 do
        @subscribers.subscribe("john.smith@gmail.com")
        @subscribers.subscribe("john+news.letter.2026@gmail.com")
        @subscribers.subscribe("a.b.c.d@example.com")
      end
    end
  end

  test "add takes a Gmail address scattered with dots from an admin" do
    assert @subscribers.add("j.o.h.n.smith@gmail.com").listed?
  end

  test "subscribe adds no row and mails nothing while the account cannot send" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        assert_not @subscribers.subscribe("new@example.com").persisted?
      end
    end
  end

  test "subscribe adds no row for an account with no sender" do
    account_senders(:davids).destroy

    assert_no_difference -> { Subscriber.count } do
      accounts(:davids_account).reload.subscribers.subscribe("new@example.com")
    end
  end

  test "request_confirmation spends none of the address's attempts while the account cannot send" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_no_changes -> { subscribers(:unsubscribed).reload.attributes.slice("confirmations_count", "confirmation_sent_at") } do
        @subscribers.subscribe(subscribers(:unsubscribed).email)
        subscribers(:unsubscribed).request_confirmation
      end
    end

    account_senders(:davids).update!(from_address: "leo@newsletter.example")

    assert_enqueued_emails 1 do
      subscribers(:unsubscribed).reload.request_confirmation
    end
  end

  test "subscribe ignores an invalid address" do
    assert_no_enqueued_emails do
      assert_no_difference -> { Subscriber.count } do
        @subscribers.subscribe("not an address")
      end
    end
  end

  test "confirm confirms an unconfirmed row once" do
    subscribers(:unconfirmed).confirm
    assert subscribers(:unconfirmed).active?

    assert_no_changes -> { subscribers(:unconfirmed).reload.confirmed_at } do
      subscribers(:unconfirmed).confirm
    end
  end

  test "confirm with no link leaves an unsubscribed or bounced row where it is" do
    @subscribers.subscribe(subscribers(:unsubscribed).email)
    @subscribers.subscribe(subscribers(:bounced).email)

    subscribers(:unsubscribed).reload.confirm
    subscribers(:bounced).reload.confirm

    assert subscribers(:unsubscribed).reload.unsubscribed?
    assert subscribers(:bounced).reload.bounced?
  end

  test "confirm_using_token confirms an unconfirmed row once" do
    token = confirmation_token_for(subscribers(:unconfirmed))

    assert subscribers(:unconfirmed).confirm_using_token(token)
    assert subscribers(:unconfirmed).reload.active?

    assert_no_changes -> { subscribers(:unconfirmed).reload.confirmed_at } do
      assert_not subscribers(:unconfirmed).confirm_using_token(token)
    end
  end

  test "confirm_using_token starts the journey for the person, with the row written beside the confirmation" do
    subscriber = subscribers(:unconfirmed)

    assert_enqueued_with job: Journey::DeliveryJob do
      assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
    end

    delivery = subscriber.journey_deliveries.sole
    assert delivery.pending?
    assert_equal journey_emails(:davids), delivery.email

    perform_enqueued_jobs only: Journey::DeliveryJob
    assert delivery.reload.sent_at?
    assert_equal [ subscriber.email ], ActionMailer::Base.deliveries.last.to
  end

  test "confirm_using_token does not confirm when the journey's row cannot be written" do
    Journey::Email.any_instance.stubs(:deliver_to).raises(ActiveRecord::StatementInvalid)

    assert_raises(ActiveRecord::StatementInvalid) do
      subscribers(:unconfirmed).confirm_using_token confirmation_token_for(subscribers(:unconfirmed))
    end

    assert subscribers(:unconfirmed).reload.unconfirmed?
  end

  test "confirm_using_token starts the confirmation's journey and no other, with its first email alone" do
    journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    second = journey.emails.create!(subject: "One more thing", body: "<p>Read the archive.</p>", active: true, delay_days: 2)
    journey_emails(:davids_goodbye).activate
    subscriber = subscribers(:unconfirmed)

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
    end

    assert_equal [ journey_emails(:davids) ], subscriber.journey_deliveries.map(&:email)
    assert_equal [ "subscriber_confirmed" ], subscriber.journey_runs.map(&:trigger)
    assert_empty second.deliveries
    assert_empty journey_emails(:other_accounts).deliveries
  end

  test "confirm_using_token confirms with no journey started while its email is off, or there is none" do
    journey_emails(:davids).deactivate

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert subscribers(:unconfirmed).confirm_using_token(confirmation_token_for(subscribers(:unconfirmed)))
    end
    assert_empty subscribers(:unconfirmed).journey_deliveries

    journey_emails(:davids).destroy!
    @subscribers.subscribe(subscribers(:unsubscribed).email)

    assert subscribers(:unsubscribed).confirm_using_token(confirmation_token_for(subscribers(:unsubscribed)))
    assert_equal 0, Journey::Delivery.count
    assert_empty subscribers(:unconfirmed).journey_runs
    assert_empty subscribers(:unsubscribed).journey_runs
  end

  test "confirm_using_token mails each admin who has the notification on, and nobody else" do
    subscriber = subscribers(:unconfirmed)

    assert_enqueued_emails 2 do
      assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
    end

    assert_enqueued_email_with NotificationMailer, :new_subscriber, args: [ users(:leo), subscriber ]
    assert_enqueued_email_with NotificationMailer, :new_subscriber, args: [ users(:mia), subscriber ]
  end

  test "confirm_using_token mails no admin who switched the notification off or was deactivated" do
    users(:leo).settings.update!(new_subscriber_notifications: false)
    users(:mia).update!(active: false)

    assert_no_enqueued_emails do
      assert subscribers(:unconfirmed).confirm_using_token(confirmation_token_for(subscribers(:unconfirmed)))
    end
  end

  test "confirm_using_token mails no admin who is not verified" do
    subscriber = subscribers(:unconfirmed)
    users(:mia).update!(verified_at: nil)

    assert_enqueued_emails 1 do
      assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
    end

    assert_enqueued_email_with NotificationMailer, :new_subscriber, args: [ users(:leo), subscriber ]
  end

  test "a refused link, confirm and add mail no admin" do
    assert_no_enqueued_emails do
      assert_not subscribers(:unconfirmed).confirm_using_token("nope")
      subscribers(:unconfirmed).confirm
      @subscribers.add("new@example.com")
    end
  end

  test "a refused link starts no journey" do
    assert_no_difference -> { Journey::Delivery.count } do
      assert_not subscribers(:unconfirmed).confirm_using_token("nope")
    end
  end

  test "a person who unsubscribes and confirms again is not sent the journey twice" do
    subscriber = subscribers(:unconfirmed)
    subscriber.confirm_using_token confirmation_token_for(subscriber)
    subscriber.unsubscribe
    subscriber.request_confirmation

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert_no_difference -> { Journey::Delivery.count } do
        assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
      end
    end

    assert subscriber.reload.active?
  end

  test "unsubscribe starts the unsubscribe journey, with the row written beside the date" do
    journey_emails(:davids_goodbye).activate
    subscriber = subscribers(:active)

    freeze_time do
      assert_enqueued_with job: Journey::DeliveryJob do
        subscriber.unsubscribe
      end

      delivery = journey_emails(:davids_goodbye).deliveries.sole
      assert_equal subscriber, delivery.subscriber
      assert_equal Time.current, delivery.deliver_at
      assert delivery.pending?
    end

    run = subscriber.journey_runs.find_by!(trigger: "subscriber_unsubscribed")
    assert run.in_progress?

    perform_enqueued_jobs only: Journey::DeliveryJob

    assert journey_emails(:davids_goodbye).deliveries.sole.sent_at?
    assert_equal [ subscriber.email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Sorry to see you go", ActionMailer::Base.deliveries.last.subject
    assert subscriber.reload.unsubscribed?
    assert run.reload.finished?
  end

  test "unsubscribe does not record the date when the journey's row cannot be written" do
    journey_emails(:davids_goodbye).activate
    Journey::Email.any_instance.stubs(:deliver_to).raises(ActiveRecord::StatementInvalid)

    assert_raises(ActiveRecord::StatementInvalid) { subscribers(:active).unsubscribe }

    assert subscribers(:active).reload.active?
    assert_empty subscribers(:active).journey_runs.where(trigger: "subscriber_unsubscribed")
  end

  test "unsubscribe starts the journey only for someone who was on the list" do
    journey_emails(:davids_goodbye).activate

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert_no_difference -> { Journey::Delivery.count } do
        %i[ unconfirmed unsubscribed bounced stopped ].each { subscribers(it).unsubscribe }
      end
    end

    assert subscribers(:unconfirmed).reload.unsubscribed_at?
  end

  test "unsubscribe starts the journey once for a person, however often they leave" do
    journey_emails(:davids_goodbye).activate
    subscriber = subscribers(:unconfirmed)
    subscriber.confirm_using_token confirmation_token_for(subscriber)

    assert_difference -> { journey_emails(:davids_goodbye).deliveries.count }, +1 do
      2.times { subscriber.unsubscribe }
    end

    subscriber.request_confirmation
    assert subscriber.confirm_using_token(confirmation_token_for(subscriber))

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert_no_difference -> { Journey::Delivery.count } do
        subscriber.unsubscribe
      end
    end

    assert subscriber.reload.unsubscribed?
  end

  test "unsubscribe mails nobody while the journey's email is off, or there is none" do
    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      subscribers(:active).unsubscribe
    end

    journey_emails(:davids_goodbye).destroy!
    subscriber = @subscribers.add("leaving@example.com")

    assert_no_difference -> { Journey::Delivery.count } do
      subscriber.unsubscribe
    end

    assert subscriber.reload.unsubscribed?
  end

  test "confirm and add start no journey" do
    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      assert_no_difference -> { Journey::Delivery.count } do
        subscribers(:unconfirmed).confirm
        @subscribers.add("new@example.com")
        @subscribers.add(subscribers(:unconfirmed).email)
      end
    end
  end

  test "confirm_and_welcome confirms an unconfirmed row and starts its journey, with no admin mailed" do
    subscriber = subscribers(:unconfirmed)

    assert_no_enqueued_emails do
      assert_enqueued_jobs 1, only: Journey::DeliveryJob do
        subscriber.confirm_and_welcome
      end
    end

    assert subscriber.reload.active?
    assert_equal [ "subscriber_confirmed" ], subscriber.journey_runs.map(&:trigger)
    assert_equal [ journey_emails(:davids) ], subscriber.journey_deliveries.map(&:email)
  end

  test "confirm_and_welcome leaves an unsubscribed or bounced row where it is, with no journey" do
    @subscribers.subscribe(subscribers(:unsubscribed).email)
    @subscribers.subscribe(subscribers(:bounced).email)

    assert_no_difference -> { Journey::Run.count } do
      subscribers(:unsubscribed).reload.confirm_and_welcome
      subscribers(:bounced).reload.confirm_and_welcome
    end

    assert subscribers(:unsubscribed).reload.unsubscribed?
    assert subscribers(:bounced).reload.bounced?
  end

  test "confirm starts no journey run" do
    assert_no_difference -> { Journey::Run.count } do
      subscribers(:unconfirmed).confirm
    end

    assert subscribers(:unconfirmed).reload.active?
  end

  test "confirm_using_token refuses a malformed token, the permanent one and one made for something else" do
    subscriber = subscribers(:unconfirmed)

    assert_not subscriber.confirm_using_token("nope")
    assert_not subscriber.confirm_using_token(subscriber.token)
    assert_not subscriber.confirm_using_token(subscriber.to_sgid(for: "something_else").to_s)
    assert_not subscriber.confirm_using_token(subscriber.to_sgid(for: Subscriber::CONFIRMATION_TOKEN_PURPOSE).to_s)

    assert subscriber.reload.unconfirmed?
  end

  test "confirm_using_token refuses a token once it has expired" do
    token = confirmation_token_for(subscribers(:unconfirmed))

    travel Subscriber::CONFIRMATION_TOKEN_EXPIRATION - 1.minute
    assert subscribers(:unconfirmed).confirmable_using_token?(token)

    travel 2.minutes
    assert_not subscribers(:unconfirmed).confirm_using_token(token)
    assert subscribers(:unconfirmed).reload.unconfirmed?
  end

  test "confirm_using_token refuses a token made for another subscriber" do
    @subscribers.subscribe(subscribers(:unsubscribed).email)
    token = confirmation_token_for(subscribers(:unsubscribed))

    assert_not subscribers(:unconfirmed).confirm_using_token(token)
    assert subscribers(:unconfirmed).reload.unconfirmed?
  end

  test "confirm_using_token refuses a token older than a newer confirmation" do
    subscriber = subscribers(:unconfirmed)
    older = confirmation_token_for(subscriber)

    subscriber.update!(confirmations_count: 0)
    assert_enqueued_emails(1) { subscriber.request_confirmation }

    assert_not subscriber.confirm_using_token(older)
    assert subscriber.reload.unconfirmed?
    assert subscriber.confirm_using_token(confirmation_token_for(subscriber))
  end

  test "find_by_confirmation_token finds the row only on its own account and while the link holds" do
    token = confirmation_token_for(subscribers(:unconfirmed))

    assert_equal subscribers(:unconfirmed), @subscribers.find_by_confirmation_token(token)
    assert_nil accounts(:other_account).subscribers.find_by_confirmation_token(token)
    assert_nil @subscribers.find_by_confirmation_token("nope")
    assert_nil @subscribers.find_by_confirmation_token(subscribers(:unconfirmed).token)

    subscribers(:unconfirmed).confirm_using_token(token)
    assert_nil @subscribers.find_by_confirmation_token(token)
  end

  test "a link mailed before the unsubscribe changes nothing" do
    token = confirmation_token_for(subscribers(:unconfirmed))
    subscribers(:unconfirmed).confirm_using_token(token)
    subscribers(:unconfirmed).unsubscribe

    assert_not subscribers(:unconfirmed).confirm_using_token(token)
    assert subscribers(:unconfirmed).reload.unsubscribed?
  end

  test "a link asked for after the unsubscribe brings the row back" do
    @subscribers.subscribe(subscribers(:unsubscribed).email)

    subscribers(:unsubscribed).confirm_using_token confirmation_token_for(subscribers(:unsubscribed))

    assert subscribers(:unsubscribed).reload.active?
    assert_nil subscribers(:unsubscribed).unsubscribed_at
  end

  test "a link mailed before the bounce changes nothing" do
    token = confirmation_token_for(subscribers(:unconfirmed))
    subscribers(:unconfirmed).bounce

    assert_not subscribers(:unconfirmed).confirm_using_token(token)
    assert subscribers(:unconfirmed).reload.bounced?
  end

  test "a link asked for after the bounce brings the row back" do
    @subscribers.subscribe(subscribers(:bounced).email)

    subscribers(:bounced).confirm_using_token confirmation_token_for(subscribers(:bounced))

    assert subscribers(:bounced).reload.active?
    assert_nil subscribers(:bounced).bounced_at
    assert_equal 0, subscribers(:bounced).confirmations_count
  end

  test "a link brings back a row that unsubscribed and bounced when asked for after both" do
    subscribers(:unsubscribed).bounce
    travel 1.minute
    @subscribers.subscribe(subscribers(:unsubscribed).email)

    subscribers(:unsubscribed).confirm_using_token confirmation_token_for(subscribers(:unsubscribed))
    assert subscribers(:unsubscribed).reload.active?
  end

  test "a link does not bring back a row that bounced after its one confirmation was asked for" do
    @subscribers.subscribe(subscribers(:unsubscribed).email)
    token = confirmation_token_for(subscribers(:unsubscribed))
    travel 1.minute
    subscribers(:unsubscribed).bounce

    assert_not subscribers(:unsubscribed).confirm_using_token(token)
    assert subscribers(:unsubscribed).reload.bounced?

    travel 1.minute
    assert_no_enqueued_emails { @subscribers.subscribe(subscribers(:unsubscribed).email) }
    assert_not subscribers(:unsubscribed).reload.confirm_using_token(token)
    assert subscribers(:unsubscribed).reload.bounced?
  end

  test "a link does not bring back a bounced row an admin had stopped" do
    @subscribers.subscribe(subscribers(:bounced).email)
    token = confirmation_token_for(subscribers(:bounced))
    subscribers(:bounced).deactivate

    assert_not subscribers(:bounced).confirm_using_token(token)
    assert subscribers(:bounced).reload.bounced?
    assert subscribers(:bounced).deactivated_at?
  end

  test "a link made for a stopped row does not confirm it" do
    assert_not subscribers(:stopped).confirm_using_token(confirmation_token_for(subscribers(:stopped)))

    subscribers(:unconfirmed).deactivate
    assert_not subscribers(:unconfirmed).confirm_using_token(confirmation_token_for(subscribers(:unconfirmed)))
    assert_nil subscribers(:unconfirmed).reload.confirmed_at
  end

  test "a link works again once a row stopped after it was mailed is resumed" do
    token = confirmation_token_for(subscribers(:unconfirmed))
    subscribers(:unconfirmed).deactivate
    subscribers(:unconfirmed).activate

    assert subscribers(:unconfirmed).confirm_using_token(token)
  end

  test "a row that came back bounces again when the provider says so" do
    @subscribers.subscribe(subscribers(:bounced).email)
    subscribers(:bounced).confirm_using_token confirmation_token_for(subscribers(:bounced))

    subscribers(:bounced).bounce

    assert subscribers(:bounced).reload.bounced?
  end

  test "confirm does not resume a stopped row" do
    subscribers(:unconfirmed).deactivate

    subscribers(:unconfirmed).confirm

    assert subscribers(:unconfirmed).reload.deactivated?
    assert_nil subscribers(:unconfirmed).confirmed_at
  end

  test "add puts a new address on the list confirmed, with no mail" do
    assert_no_enqueued_emails do
      assert @subscribers.add("new@example.com").active?
    end
  end

  test "add confirms an unconfirmed address, with no mail" do
    assert_no_enqueued_emails do
      assert @subscribers.add(subscribers(:unconfirmed).email).listed?
    end

    assert subscribers(:unconfirmed).reload.active?
  end

  test "add never brings back an unsubscribed, bounced or stopped address" do
    assert_not @subscribers.add(subscribers(:unsubscribed).email).listed?
    assert_not @subscribers.add(subscribers(:bounced).email).listed?
    assert_not @subscribers.add(subscribers(:stopped).email).listed?

    assert subscribers(:unsubscribed).reload.unsubscribed?
    assert subscribers(:bounced).reload.bounced?
    assert subscribers(:stopped).reload.deactivated?
  end

  test "add gives one error to a row it leaves off the list, naming what kept it off" do
    assert_equal({ email: [ I18n.t("subscribers_not_address") ] }, @subscribers.add("not an address").errors.to_hash)
    assert_equal({ email: [ I18n.t("subscribers_batch_refusal_unsubscribed") ] }, @subscribers.add(subscribers(:unsubscribed).email).errors.to_hash)
    assert_equal({ email: [ I18n.t("subscribers_batch_refusal_bounced") ] }, @subscribers.add(subscribers(:bounced).email).errors.to_hash)
    assert_equal({ email: [ I18n.t("subscribers_batch_refusal_deactivated") ] }, @subscribers.add(subscribers(:stopped).email).errors.to_hash)
    assert_empty @subscribers.add("new@example.com").errors
  end

  test "unsubscribe and bounce keep their first date" do
    assert_no_changes -> { subscribers(:unsubscribed).reload.unsubscribed_at } do
      subscribers(:unsubscribed).unsubscribe
    end

    assert_no_changes -> { subscribers(:bounced).reload.bounced_at } do
      subscribers(:bounced).bounce
    end
  end

  test "activate returns a stopped row to what it was" do
    subscribers(:stopped).activate
    assert subscribers(:stopped).active?

    subscribers(:unconfirmed).deactivate
    subscribers(:unconfirmed).activate
    assert subscribers(:unconfirmed).unconfirmed?
  end

  private
    def confirmation_token_for(subscriber)
      subscriber.reload.send(:generate_confirmation_token)
    end

  test "destroy takes the deliveries and the journey history, and the post counts one fewer" do
    subscriber = subscribers(:active)

    assert_difference -> { posts(:sent).reload.deliveries_count }, -1 do
      subscriber.destroy!
    end

    assert_not Post::Delivery.exists?(subscriber_id: subscriber.id)
    assert_not Journey::Delivery.exists?(subscriber_id: subscriber.id)
    assert_not Journey::Run.exists?(subscriber_id: subscriber.id)
  end

  test "an address deleted after it unsubscribed is added again as new" do
    subscribers(:unsubscribed).destroy!

    assert @subscribers.add("dan@example.com").active?
  end
end
