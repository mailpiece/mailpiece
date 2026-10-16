require "test_helper"

class Post::ReleasableTest < ActiveSupport::TestCase
  test "a destination is a visibility and whether it is mailed, in the order offered" do
    assert_equal [ [ "web_and_email", "listed", true ], [ "email", "email_only", true ], [ "web", "listed", false ], [ "link", "unlisted", false ] ],
      Post::Destination.all.map { |destination| [ destination.name, destination.visibility, destination.mailed? ] }
  end

  test "the ones that mail are offered only with a sender and someone to mail" do
    assert_equal %w[ web_and_email email web link ], posts(:draft).destinations.map(&:name)

    subscribers(:active).deactivate
    assert_equal %w[ web link ], posts(:draft).destinations.map(&:name)
    assert_nil posts(:draft).destination_named("email")

    subscribers(:active).activate
    account_senders(:davids).update!(from_address: nil)
    assert_equal %w[ web link ], posts(:draft).reload.destinations.map(&:name)
  end

  test "a draft proposes the widest destination its visibility allows" do
    assert_equal "web_and_email", posts(:draft).destination.name

    posts(:draft).update! visibility: "unlisted"
    assert_equal "link", posts(:draft).destination.name

    posts(:draft).update! visibility: "email_only"
    assert_equal "email", posts(:draft).destination.name

    subscribers(:active).deactivate
    assert_equal "web", posts(:draft).destination.name

    posts(:draft).update! visibility: "listed"
    assert_equal "web", posts(:draft).destination.name
  end

  test "a scheduled draft proposes what its schedule holds" do
    assert_equal "web_and_email", posts(:scheduled).destination.name

    posts(:scheduled).update! scheduled_delivery: false
    assert_equal "web", posts(:scheduled).destination.name

    posts(:scheduled).update! visibility: "unlisted"
    assert_equal "link", posts(:scheduled).destination.name

    posts(:scheduled).update! visibility: "email_only", scheduled_delivery: true
    assert_equal "email", posts(:scheduled).destination.name
  end

  test "release_to sets the visibility, publishes, and sends only where the destination is mailed" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      posts(:draft).release_to posts(:draft).destination_named("email")
    end
    assert posts(:draft).reload.email_only?
    assert posts(:draft).sent?

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      posts(:scheduled).release_to posts(:scheduled).destination_named("link")
    end
    assert posts(:scheduled).reload.unlisted?
    assert posts(:scheduled).published?
    assert_not posts(:scheduled).sent?
    assert_nil posts(:scheduled).scheduled_posting_at
  end

  test "release_to leaves a draft alone when the list emptied since the destination was offered" do
    destination = posts(:draft).destination_named("email")
    subscribers(:active).deactivate

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      posts(:draft).release_to destination
    end

    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
  end

  test "release_to does nothing to a published post" do
    posts(:unlisted).release_to posts(:unlisted).destination_named("web_and_email")

    assert posts(:unlisted).reload.unlisted?
    assert_not posts(:unlisted).sent?
  end

  test "schedule_to stores the visibility and whether to send with the time" do
    assert posts(:draft).schedule_to(posts(:draft).destination_named("email"), at: 1.day.from_now)

    assert posts(:draft).reload.scheduled?
    assert posts(:draft).email_only?
    assert posts(:draft).scheduled_delivery?
  end

  test "schedule_to judges the visibility the post is going to, not the one it has" do
    posts(:draft).update! visibility: "email_only"

    assert posts(:draft).schedule_to(posts(:draft).destination_named("web"), at: 1.day.from_now)

    assert posts(:draft).reload.listed?
    assert_not posts(:draft).scheduled_delivery?
  end

  test "schedule_to changes nothing when the time is not in the future" do
    assert_not posts(:draft).schedule_to(posts(:draft).destination_named("link"), at: 1.hour.ago)

    assert posts(:draft).listed?
    assert_not posts(:draft).changed?
    assert posts(:draft).errors.any?
    assert_not posts(:draft).reload.scheduled?
  end

  test "publish_to publishes under a past date where it was told to, and mails nothing" do
    assert_no_enqueued_jobs do
      assert posts(:draft).publish_to(posts(:draft).destination_named("link"), at: "2019-03-01T09:30")
    end

    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:draft).reload.published_at
    assert posts(:draft).unlisted?
    assert_not posts(:draft).sent?
  end

  test "publish_to publishes what was to be mailed too, and leaves it unsent" do
    assert_no_enqueued_jobs do
      assert posts(:draft).publish_to(posts(:draft).destination_named("web_and_email"), at: "2019-03-01T09:30")
    end

    assert_equal Time.zone.local(2019, 3, 1, 9, 30), posts(:draft).reload.published_at
    assert posts(:draft).listed?
    assert_not posts(:draft).sent?
    assert_empty posts(:draft).deliveries
  end

  test "publish_to is refused by email only" do
    assert_no_enqueued_jobs do
      assert_not posts(:draft).publish_to(posts(:draft).destination_named("email"), at: 1.year.ago)
    end

    assert posts(:draft).errors.any?
    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
  end

  test "publish_to with no date publishes a draft now, where it was told to" do
    assert_no_enqueued_jobs do
      assert posts(:draft).publish_to(posts(:draft).destination_named("link"))
    end

    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
    assert posts(:draft).unlisted?
    assert_not posts(:draft).sent?
  end

  test "publish_to gives a page to an issue that went out by email only, and does nothing to a post that has one" do
    assert posts(:email_only).publish_to(posts(:email_only).destination_for(nil))
    assert posts(:email_only).reload.listed?

    assert_no_changes -> { posts(:unlisted).reload.attributes } do
      assert posts(:unlisted).publish_to(posts(:unlisted).destination_named("web"), at: "2019-03-01T09:30")
    end
  end

  test "destination_for is the one named if it is offered, and with no name the post's own visibility" do
    subscribers(:active).deactivate
    posts(:draft).update! visibility: "unlisted"

    assert_equal "link", posts(:draft).destination_for("link").name
    assert_nil posts(:draft).destination_for("email")
    assert_nil posts(:draft).destination_for("everywhere")

    assert_equal "unlisted", posts(:draft).destination_for(nil).visibility
    assert_not posts(:draft).destination_for("").mailed?
    assert posts(:draft).destination_for(nil, mailed: true).mailed?
  end

  test "release sends a draft where it was told to, right now" do
    assert posts(:draft).release(to: posts(:draft).destination_named("link"))
    assert posts(:draft).reload.published?
    assert posts(:draft).unlisted?
  end

  test "release only sends a published post, once" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      assert posts(:unlisted).release
      assert_not posts(:unlisted).release
    end

    assert posts(:unlisted).reload.sent?
    assert posts(:unlisted).unlisted?
  end
end
