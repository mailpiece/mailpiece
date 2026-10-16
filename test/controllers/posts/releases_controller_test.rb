require "test_helper"

class Posts::ReleasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create publishes a draft and sends it" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "web_and_email" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "on its way", flash[:notice]
    assert posts(:draft).reload.published?
    assert posts(:draft).listed?
    assert posts(:draft).sent?
    assert_equal [ subscribers(:active) ], posts(:draft).deliveries.map(&:subscriber)
  end

  test "create sends a draft by email only" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "email" }
    end

    assert_match "on its way", flash[:notice]
    assert posts(:draft).reload.email_only?
    assert posts(:draft).sent?
  end

  test "create publishes on the web without sending, with or without a sender" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "web" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Published on the web", flash[:notice]
    assert posts(:draft).reload.published?
    assert posts(:draft).listed?
    assert_not posts(:draft).sent?
  end

  test "create publishes by link, whatever the draft's visibility was" do
    posts(:draft).update! visibility: "email_only"

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "link" }
    end

    assert posts(:draft).reload.published?
    assert posts(:draft).unlisted?
    assert_not posts(:draft).sent?
  end

  test "create saves what is on the editor before it releases" do
    post post_release_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true, destination: "link" }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).published?
  end

  test "create releases nothing when the save fails, and goes back to the editor with why" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { post: { title: "The file", visibility: "nowhere" }, auto_save: true, destination: "email" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "Visibility", flash[:alert]
    assert posts(:draft).reload.draft?
    assert_equal "How to keep a contractor file", posts(:draft).title
  end

  test "create releases a post without a title as Untitled" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { post: { title: "" }, auto_save: true, destination: "web_and_email" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert posts(:draft).reload.sent?
    assert_equal "Untitled", posts(:draft).title
  end

  test "create from a draft's editor left open on a post published since changes and sends nothing" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:unlisted)), params: { post: { title: "An old draft" }, auto_save: true, destination: "web_and_email" }
    end

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_match "published since", flash[:alert]
    assert_equal "Notes for the March workshop", posts(:unlisted).reload.title
    assert posts(:unlisted).unlisted?
    assert_not posts(:unlisted).sent?
  end

  test "create on a published post sends it as it is, with what its editor holds saved first" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:unlisted)), params: { post: { title: "Workshop notes" }, destination: "web" }
    end

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_match "on its way", flash[:notice]
    assert posts(:unlisted).reload.sent?
    assert posts(:unlisted).unlisted?
    assert_equal "Workshop notes", posts(:unlisted).title
  end

  test "create on a sent post sends nothing again" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      assert_no_changes -> { posts(:sent).reload.sent_at } do
        post post_release_path(posts(:sent))
      end
    end

    assert_redirected_to edit_post_path(posts(:sent))
    assert_match "already sent", flash[:notice]
  end

  test "create on a published post without confirmed subscribers says nothing was sent" do
    subscribers(:active).deactivate

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:unlisted))
    end

    assert_match "nothing was sent", flash[:notice]
    assert_not posts(:unlisted).reload.sent?
  end

  test "create on a published post without a complete sender sends nothing" do
    account_senders(:davids).update!(from_address: nil)

    post post_release_path(posts(:unlisted)), params: { post: { title: "Workshop notes" } }

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_equal "Email sending is not set up", flash[:alert]
    assert_not posts(:unlisted).reload.sent?
    assert_equal "Notes for the March workshop", posts(:unlisted).title
  end

  test "create refuses a draft an email it cannot send, and changes nothing" do
    subscribers(:active).deactivate

    post post_release_path(posts(:draft)), params: { destination: "email" }
    assert_response :forbidden

    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
  end

  test "create with the date left as it was shown releases right now, however long ago that was" do
    assert_enqueued_jobs 1, only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "web_and_email", day: "2019-03-01", hour: "7", shown: "2019-03-01T07:00" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "on its way", flash[:notice]
    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
    assert posts(:draft).sent?
    assert_not posts(:draft).scheduled?
  end

  test "create with the date moved from the one shown releases nothing, and goes back to the editor with why" do
    day, shown = 2.days.from_now.to_date.iso8601, shown_now

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true, destination: "web_and_email", day: day, hour: "7", shown: shown }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "The date was changed, so nothing was published. Try again.", flash[:alert]
    assert posts(:draft).reload.draft?
    assert_not posts(:draft).scheduled?
    assert_equal "The file", posts(:draft).title

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { destination: "web_and_email", day: "2019-03-01", hour: "7", shown: shown }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "The date was changed", flash[:alert]
    assert posts(:draft).reload.draft?
  end

  test "create with the date moved from the one shown answers Turbo with a flash that says so" do
    post post_release_path(posts(:draft)), params: { destination: "web", day: 2.days.from_now.to_date.iso8601, hour: "7", shown: shown_now },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_includes response.body, "The date was changed, so nothing was published. Try again."
    assert posts(:draft).reload.draft?
    assert_not posts(:draft).scheduled?
  end

  test "create with a day left empty releases right now" do
    post post_release_path(posts(:draft)), params: { destination: "web", day: "", hour: "3", shown: shown_now }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
  end

  test "create on a published post without a complete sender answers Turbo with a flash that says so" do
    account_senders(:davids).update!(from_address: nil)

    post post_release_path(posts(:unlisted)), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_includes response.body, "Email sending is not set up"
    assert_not posts(:unlisted).reload.sent?
  end

  test "create with no destination, or one that does not exist, releases nothing" do
    post post_release_path(posts(:draft))
    assert_response :forbidden

    post post_release_path(posts(:draft)), params: { destination: "everywhere" }
    assert_response :forbidden

    assert posts(:draft).reload.draft?
  end

  test "a post of another account is not found" do
    post post_release_path(posts(:other_accounts)), params: { destination: "web_and_email" }
    assert_response :not_found
    assert_not posts(:other_accounts).reload.sent?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_release_path(posts(:draft)), params: { post: { title: "No" }, destination: "web_and_email" }
    end

    assert_response :forbidden
    assert posts(:draft).reload.draft?
    assert_not_equal "No", posts(:draft).title
  end

  private
    # What a draft's date is drawn as: the hour now running.
    def shown_now
      Time.zone.now.strftime("%Y-%m-%dT%H:00")
    end
end
