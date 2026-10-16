require "test_helper"

class Post::DeliverableTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "deliver publishes a draft and writes a delivery for each active subscriber" do
    assert_enqueued_with job: Post::QueueDeliveriesJob, args: [ posts(:draft) ] do
      assert posts(:draft).deliver
    end

    assert posts(:draft).published?
    assert posts(:draft).sent?
    assert_equal [ subscribers(:active) ], posts(:draft).deliveries.map(&:subscriber)
    assert_equal 1, posts(:draft).reload.deliveries_count
  end

  test "deliver sends a published post without moving its date" do
    assert_no_changes -> { posts(:unlisted).reload.published_at } do
      assert posts(:unlisted).deliver
    end
  end

  test "deliver sends a post once" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      assert_no_changes -> { posts(:sent).reload.sent_at } do
        assert_no_difference -> { Post::Delivery.count } do
          assert_not posts(:sent).deliver
        end
      end
    end
  end

  test "deliver with nobody to send to publishes and stays unsent" do
    subscribers(:active).unsubscribe

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      assert_not posts(:draft).deliver
    end

    assert posts(:draft).reload.published?
    assert_nil posts(:draft).sent_at
  end

  test "deliver does nothing without a complete sender" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      assert_not posts(:draft).deliver
    end

    assert_equal [ "Email sending is not set up" ], posts(:draft).errors[:sender]
    assert posts(:draft).reload.draft?
  end

  test "queue_deliveries_now queues each delivery that has no turn yet" do
    posts(:draft).deliver

    assert_enqueued_jobs 1, only: Post::DeliveryJob do
      posts(:draft).queue_deliveries_now
    end

    assert_no_enqueued_jobs only: Post::DeliveryJob do
      posts(:draft).queue_deliveries_now
    end
  end

  test "deliver_test_to mails one copy to the address and writes no delivery" do
    assert_no_difference -> { Post::Delivery.count } do
      assert_enqueued_email_with PostMailer, :test_issue, args: [ posts(:draft), "editor@example.com" ] do
        assert posts(:draft).deliver_test_to("editor@example.com")
      end
    end
  end

  test "deliver_test_to sends nothing without a complete sender" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      assert_not posts(:draft).deliver_test_to("editor@example.com")
    end

    assert_equal [ "Email sending is not set up" ], posts(:draft).errors[:sender]
  end

  test "deliver_test_to sends nothing to what is not an address" do
    assert_no_enqueued_emails do
      assert_not posts(:draft).deliver_test_to("not an address")
    end

    assert_equal [ "Enter a valid email address for the test" ], posts(:draft).errors[:base]
  end

  test "a sent post is sending until every delivery is sent, refused or unverified" do
    assert_not posts(:sent).sending?
    assert_not posts(:draft).sending?

    posts(:sent).deliveries.first.update!(sent_at: nil)
    assert Post.find(posts(:sent).id).sending?

    posts(:sent).deliveries.first.update!(refused_at: Time.current)
    assert_not Post.find(posts(:sent).id).sending?
  end

  test "with_delivery_progress counts a list's posts at once, and a post with no deliveries has none" do
    posts = accounts(:davids_account).posts.order(:title).with_delivery_progress.index_by(&:title)

    assert_no_queries do
      assert_equal({ sent: 2, refused: 0, unverified: 0 }, posts["Three deadlines in March"].delivery_progress)
      assert_equal({ sent: 0, refused: 0, unverified: 0 }, posts["How to keep a contractor file"].delivery_progress)
    end
  end

  test "load_delivery_progress counts the posts of a page already cut from its list" do
    sent = posts(:sent)
    page = accounts(:davids_account).posts.sent.recently_published_first.offset(1).limit(1)
    accounts(:davids_account).posts.load_delivery_progress page

    assert_no_queries do
      assert_equal [ sent ], page.to_a
      assert_equal({ sent: 2, refused: 0, unverified: 0 }, page.first.delivery_progress)
    end
  end
end
