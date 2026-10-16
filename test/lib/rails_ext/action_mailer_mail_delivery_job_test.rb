require "test_helper"

# Mail sent with deliver_later fails in two ways: system mail with SMTP's own errors, a newsletter's
# mail with the MailDelivery errors its transport raises. The job answers both, each on its own terms.
class ActionMailerMailDeliveryJobTest < ActiveJob::TestCase
  test "system mail is tried again while the SMTP server is busy or out of reach" do
    [ Net::SMTPServerBusy.new("452 4.3.1 Insufficient system storage"), Net::OpenTimeout.new, Net::ReadTimeout.new ].each do |error|
      deliver_later_failing_with(error) { system_mail }

      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
      clear_enqueued_jobs
    end
  end

  test "system mail to an address the SMTP server does not know is dropped" do
    [ Net::SMTPFatalError.new("550 5.1.1 Unknown user"), Net::SMTPSyntaxError.new("501 5.1.3 Bad recipient address syntax") ].each do |error|
      deliver_later_failing_with(error) { system_mail }

      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob
    end
  end

  test "system mail the SMTP server refuses for another reason fails" do
    assert_raises Net::SMTPFatalError do
      deliver_later_failing_with(Net::SMTPFatalError.new("554 5.7.1 Relay access denied")) { system_mail }
    end

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob
  end

  test "a newsletter's mail is tried again while its transport is busy, out of reach or silent" do
    [ MailDelivery::Throttled, MailDelivery::Unavailable, MailDelivery::Unauthorized, MailDelivery::Unverified ].each do |error|
      deliver_later_failing_with(error.new("not now")) { newsletter_mail }

      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
      clear_enqueued_jobs
    end
  end

  test "a newsletter's mail its transport refuses is dropped" do
    deliver_later_failing_with(MailDelivery::Refused.new("550 5.1.1 Unknown user")) { newsletter_mail }

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob
  end

  private
    def deliver_later_failing_with(error)
      Mail::TestMailer.any_instance.stubs(:deliver!).raises(error)

      yield.deliver_later
      perform_enqueued_jobs only: ActionMailer::MailDeliveryJob
    end

    def system_mail
      UserMailer.email_change_confirmation(email_address: "new@example.com", token: "token", user: users(:leo))
    end

    def newsletter_mail
      SubscriberMailer.confirmation(subscribers(:unconfirmed), token: "token")
    end
end
