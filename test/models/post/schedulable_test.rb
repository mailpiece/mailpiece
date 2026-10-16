require "test_helper"

class Post::SchedulableTest < ActiveSupport::TestCase
  test "schedule keeps a draft a draft, with its time and whether to send" do
    assert posts(:draft).schedule(at: 1.day.from_now, deliver: true)

    assert posts(:draft).reload.scheduled?
    assert posts(:draft).draft?
    assert posts(:draft).scheduled_delivery?
  end

  test "schedule refuses a time that has passed, or none" do
    assert_not posts(:draft).schedule(at: 1.minute.ago)
    assert_not posts(:draft).schedule(at: nil)

    assert_not posts(:draft).reload.scheduled?
  end

  test "schedule reads a time written as the form writes it, and says why it refuses one that has passed" do
    assert posts(:draft).schedule(at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"))
    assert posts(:draft).reload.scheduled?

    assert_not posts(:draft).schedule(at: 1.day.ago.strftime("%Y-%m-%dT%H:%M"))
    assert_equal [ "Pick a date and time in the future to schedule" ], posts(:draft).errors[:base]
    assert_not posts(:draft).changed?
    assert posts(:draft).reload.scheduled_posting_at.future?
  end

  test "schedule refuses a published post" do
    assert_not posts(:sent).schedule(at: 1.day.from_now)

    assert_nil posts(:sent).reload.scheduled_posting_at
  end

  test "unschedule" do
    posts(:scheduled).unschedule

    assert_not posts(:scheduled).reload.scheduled?
    assert_not posts(:scheduled).scheduled_delivery?
  end

  test "publish_due_now leaves what is not due yet" do
    Post.publish_due_now

    assert posts(:scheduled).reload.draft?
  end

  test "publish_due_now publishes and sends what is due, once" do
    travel_to 2.days.from_now

    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      2.times { Post.publish_due_now }
    end

    assert posts(:scheduled).reload.published?
    assert posts(:scheduled).sent?
    assert_not posts(:scheduled).scheduled?
  end

  test "publish_due_now publishes without sending when that is what was scheduled" do
    posts(:scheduled).update!(scheduled_delivery: false)
    travel_to 2.days.from_now

    Post.publish_due_now

    assert posts(:scheduled).reload.published?
    assert_not posts(:scheduled).sent?
  end

  test "publish_due_now publishes without sending while the sender is incomplete" do
    account_senders(:davids).update!(from_address: nil)
    travel_to 2.days.from_now

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      Post.publish_due_now
    end

    assert posts(:scheduled).reload.published?
    assert_not posts(:scheduled).sent?
  end

  test "publish_due_now skips a cancelled account" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))
    travel_to 2.days.from_now

    Post.publish_due_now

    assert posts(:scheduled).reload.draft?
  end
end
