require "test_helper"

class Posts::PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create publishes without sending" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:draft)), as: :json
    end

    assert_response :created
    assert_equal true, response.parsed_body["published"]
    assert_nil response.parsed_body["sent_at"]
    assert posts(:draft).reload.published?
  end

  test "create with a past date publishes under it" do
    post post_publication_path(posts(:draft)), params: { published_at: "2019-03-01T09:30:00Z" }, as: :json

    assert_response :created
    assert_equal Time.utc(2019, 3, 1, 9, 30), posts(:draft).reload.published_at
    assert_not posts(:draft).sent?
  end

  test "create with a date still to come publishes nothing and says why" do
    post post_publication_path(posts(:draft)), params: { published_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :unprocessable_entity
    assert_match "already passed", response.parsed_body["base"].first
    assert posts(:draft).reload.draft?
  end

  test "create on a post without a title calls it Untitled" do
    posts(:draft).update!(title: nil)

    post post_publication_path(posts(:draft)), as: :json

    assert_response :created
    assert_equal "Untitled", response.parsed_body["title"]
    assert_equal "Untitled", posts(:draft).reload.title
  end

  test "create on a published post keeps its date" do
    assert_no_changes -> { posts(:sent).reload.published_at } do
      post post_publication_path(posts(:sent)), as: :json
      post post_publication_path(posts(:sent)), params: { published_at: "2019-03-01T09:30:00Z" }, as: :json
    end

    assert_response :created
  end

  test "an email-only post is not published on the web" do
    posts(:draft).update! visibility: "email_only"

    post post_publication_path(posts(:draft)), as: :json

    assert_response :forbidden
    assert_equal "This post goes by email only and has not been sent, so it cannot be published on the web. It is released by sending it.", response.parsed_body["error"]
    assert posts(:draft).reload.draft?
  end

  test "create as JSON to a destination the draft is not offered is refused with why" do
    post post_publication_path(posts(:draft)), params: { destination: "everywhere" }, as: :json

    assert_response :forbidden
    assert_equal "This post cannot go to that destination", response.parsed_body["error"]
    assert posts(:draft).reload.draft?
  end

  test "create as JSON takes no visibility beside the fields: the destination decides it" do
    post post_publication_path(posts(:draft)), params: { title: "The file", visibility: "unlisted" }, as: :json

    assert_response :created
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).listed?
  end

  test "create from the editor publishes a draft under the past date picked, and mails nothing" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true, destination: "link", day: "2019-03-01", hour: "7", shown: shown_now }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Published on the web", flash[:notice]
    assert_equal Time.zone.local(2019, 3, 1, 7), posts(:draft).reload.published_at
    assert posts(:draft).unlisted?
    assert_not posts(:draft).sent?
    assert_equal "The file", posts(:draft).title
  end

  test "create from the editor publishes what was to be mailed too, unsent" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:draft)), params: { destination: "web_and_email", day: "2019-03-01", hour: "7", shown: shown_now }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Published on the web", flash[:notice]
    assert_equal Time.zone.local(2019, 3, 1, 7), posts(:draft).reload.published_at
    assert posts(:draft).listed?
    assert_not posts(:draft).sent?
    assert_empty posts(:draft).deliveries

    follow_redirect!
    assert_select "button.post-actions__primary:not([data-turbo-confirm])", text: "Save"
  end

  test "create from the editor publishes a scheduled post under the past date picked, off its schedule and unsent" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:scheduled)), params: { destination: "web_and_email", day: "2019-03-01", hour: "7" }
    end

    assert_redirected_to edit_post_path(posts(:scheduled))
    assert_equal Time.zone.local(2019, 3, 1, 7), posts(:scheduled).reload.published_at
    assert_not posts(:scheduled).scheduled?
    assert_not posts(:scheduled).scheduled_delivery?
    assert_not posts(:scheduled).sent?
    assert_empty posts(:scheduled).deliveries
  end

  test "create from the editor goes where it is told, whatever the draft's visibility was" do
    posts(:draft).update! visibility: "email_only"

    post post_publication_path(posts(:draft)), params: { destination: "web", day: "2019-03-01", hour: "7" }

    assert_redirected_to edit_post_path(posts(:draft))
    assert posts(:draft).reload.published?
    assert posts(:draft).listed?
    assert_not posts(:draft).sent?
  end

  test "create from the editor publishes nothing by email only, and goes back to the editor with why" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:draft)), params: { destination: "email", day: "2019-03-01", hour: "7", shown: shown_now }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "not sent by email", flash[:alert]
    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
    assert_not posts(:draft).sent?
  end

  test "create from the editor with a date still to come publishes nothing and says why" do
    post post_publication_path(posts(:draft)), params: { destination: "link", day: 2.days.from_now.to_date.iso8601, hour: "7" }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "already passed", flash[:alert]
    assert posts(:draft).reload.draft?
    assert posts(:draft).listed?
  end

  test "create with a day left empty publishes right now, as a date left out does" do
    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_publication_path(posts(:draft)), params: { destination: "link", day: "", hour: "7" }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_in_delta Time.current, posts(:draft).reload.published_at, 1.minute
    assert posts(:draft).unlisted?
    assert_not posts(:draft).sent?
  end

  test "create takes a day and an hour as JSON too, and a destination by its name" do
    post post_publication_path(posts(:draft)), params: { destination: "link", day: "2019-03-01", hour: 7 }, as: :json

    assert_response :created
    assert_equal Time.zone.local(2019, 3, 1, 7), posts(:draft).reload.published_at
    assert posts(:draft).unlisted?
  end

  test "create as JSON saves the fields sent beside the date, and publishes under it" do
    post post_publication_path(posts(:draft)), params: { title: "The file", summary: "What goes in it", published_at: "2019-03-01T09:30:00Z" }, as: :json

    assert_response :created
    assert_equal "The file", posts(:draft).reload.title
    assert_equal "What goes in it", posts(:draft).summary
    assert_equal Time.utc(2019, 3, 1, 9, 30), posts(:draft).published_at
  end

  test "create from the editor that publishes nothing answers Turbo with a flash that says why" do
    post post_publication_path(posts(:draft)), params: { destination: "email", day: "2019-03-01", hour: "7" },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_includes response.body, "A post published on a past date is not sent by email"
    assert_not_includes response.body, "post[title]"
    assert posts(:draft).reload.draft?
  end

  test "create from the editor publishes nothing when the save fails, or to a destination the draft is not offered" do
    post post_publication_path(posts(:draft)), params: { post: { visibility: "nowhere" }, auto_save: true, destination: "link", day: "2019-03-01", hour: "7" }
    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "Visibility", flash[:alert]

    post post_publication_path(posts(:draft)), params: { destination: "everywhere", day: "2019-03-01", hour: "7" }
    assert_response :forbidden
    assert_empty response.body

    assert posts(:draft).reload.draft?
  end

  test "create from a draft's editor left open on an issue mailed since gives it no page" do
    post post_publication_path(posts(:email_only)), params: { post: { title: "An old draft" }, auto_save: true, destination: "web", day: "2019-03-01", hour: "7" }

    assert_redirected_to edit_post_path(posts(:email_only))
    assert_match "published since", flash[:alert]
    assert posts(:email_only).reload.email_only?
    assert_not_equal "An old draft", posts(:email_only).title
  end

  test "create gives a page to an issue that went out by email only" do
    post post_publication_path(posts(:email_only))

    assert_redirected_to edit_post_path(posts(:email_only))
    assert posts(:email_only).reload.listed?

    get public_post_path(posts(:email_only).public_param)
    assert_response :success
  end

  test "destroy takes the page down and makes a draft of a post never mailed" do
    delete post_publication_path(posts(:unlisted))

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert posts(:unlisted).reload.draft?

    get public_post_path(posts(:unlisted).public_param)
    assert_response :not_found
  end

  test "destroy takes the page down and leaves an issue already mailed as sent" do
    assert_no_changes -> { posts(:sent).reload.sent_at } do
      delete post_publication_path(posts(:sent), format: :json)
    end

    assert_response :no_content
    assert posts(:sent).reload.email_only?

    get public_post_path(posts(:sent).public_param)
    assert_response :not_found
  end

  test "destroy does nothing to a draft" do
    assert_no_changes -> { posts(:draft).reload.attributes } do
      delete post_publication_path(posts(:draft))
    end

    assert_redirected_to edit_post_path(posts(:draft))
  end

  test "the editor offers to unpublish a post on the web, and a page to an issue without one" do
    get edit_post_path(posts(:sent))
    assert_select "button[formaction=?][name=_method][value=delete][data-turbo-confirm]", post_publication_path(posts(:sent))

    get edit_post_path(posts(:email_only))
    assert_select "button[formaction=?][name=_method][value=post]", post_publication_path(posts(:email_only))

    get edit_post_path(posts(:draft))
    assert_select "button[formaction=?]", post_publication_path(posts(:draft)), count: 0
  end

  test "a post of another account is not found" do
    post post_publication_path(posts(:other_accounts)), as: :json
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    post post_publication_path(posts(:draft)), as: :json

    assert_response :forbidden
    assert posts(:draft).reload.draft?

    post post_publication_path(posts(:draft)), params: { post: { title: "No" }, destination: "web", day: "2019-03-01", hour: "7" }

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
