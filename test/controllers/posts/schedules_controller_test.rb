require "test_helper"

class Posts::SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create schedules a draft" do
    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.day.from_now.iso8601, scheduled_delivery: true }, as: :json

    assert_response :created
    assert posts(:draft).reload.scheduled?
    assert posts(:draft).scheduled_delivery?
    assert posts(:draft).draft?
  end

  test "create with a time that has passed, or none, schedules nothing" do
    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.hour.ago.iso8601 }, as: :json
    assert_response :unprocessable_entity
    assert_match "in the future", response.parsed_body["base"].first

    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: "" }, as: :json
    assert_response :unprocessable_entity

    assert_not posts(:draft).reload.scheduled?
  end

  test "create without sending is refused for an email-only post" do
    posts(:draft).update! visibility: "email_only"

    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json
    assert_response :unprocessable_entity
    assert_match "only be scheduled with sending", response.parsed_body["base"].first

    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.day.from_now.iso8601, scheduled_delivery: true }, as: :json
    assert posts(:draft).reload.scheduled?
  end

  test "a published post cannot be scheduled" do
    post post_schedule_path(posts(:sent)), params: { scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :forbidden
    assert_equal "Only a draft is scheduled, and this post is not a draft", response.parsed_body["error"]
    assert_nil posts(:sent).reload.scheduled_posting_at
  end

  test "create as JSON to a destination the draft is not offered is refused with why" do
    post post_schedule_path(posts(:draft)), params: { destination: "everywhere", scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :forbidden
    assert_equal "This post cannot go to that destination", response.parsed_body["error"]
    assert_not posts(:draft).reload.scheduled?
  end

  test "create as JSON takes no visibility beside the fields: the destination decides it" do
    post post_schedule_path(posts(:draft)), params: { title: "The file", visibility: "unlisted", scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :created
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).listed?
  end

  test "create takes a day and an hour as JSON too, and a destination by its name" do
    day = 2.days.from_now.to_date

    post post_schedule_path(posts(:draft)), params: { destination: "link", day: day.iso8601, hour: 7 }, as: :json

    assert_response :created
    assert_equal day.in_time_zone.change(hour: 7), posts(:draft).reload.scheduled_posting_at
    assert posts(:draft).unlisted?
    assert_not posts(:draft).scheduled_delivery?
  end

  test "create as JSON saves the fields sent beside the time before it schedules" do
    post post_schedule_path(posts(:draft)), params: { title: "The file", summary: "What goes in it", scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :created
    assert_equal "The file", posts(:draft).reload.title
    assert_equal "What goes in it", posts(:draft).summary
    assert posts(:draft).scheduled?
  end

  test "create schedules a mailing as JSON before there is anyone to mail" do
    subscribers(:active).deactivate

    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.day.from_now.iso8601, scheduled_delivery: true }, as: :json

    assert_response :created
    assert posts(:draft).reload.scheduled_delivery?
  end

  test "create from the editor schedules a draft for the day and hour picked, and for where it goes" do
    day = 2.days.from_now.to_date

    assert_no_enqueued_jobs only: Post::QueueDeliveriesJob do
      post post_schedule_path(posts(:draft)), params: { destination: "web_and_email", day: day.iso8601, hour: "7", shown: shown_now }
    end

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "Scheduled", flash[:notice]
    assert_equal day.in_time_zone.change(hour: 7), posts(:draft).reload.scheduled_posting_at
    assert posts(:draft).scheduled_delivery?
    assert posts(:draft).listed?
    assert posts(:draft).draft?

    post post_schedule_path(posts(:draft)), params: { destination: "email", day: day.iso8601, hour: "7" }
    assert posts(:draft).reload.email_only?
    assert posts(:draft).scheduled_delivery?

    post post_schedule_path(posts(:draft)), params: { destination: "link", day: day.iso8601, hour: "7" }
    assert posts(:draft).reload.unlisted?
    assert_not posts(:draft).scheduled_delivery?

    post post_schedule_path(posts(:draft)), params: { destination: "web", day: day.iso8601, hour: "7" }
    assert posts(:draft).reload.listed?
    assert_not posts(:draft).scheduled_delivery?
    assert posts(:draft).draft?
  end

  test "create from the editor saves what is on it before it schedules" do
    post post_schedule_path(posts(:draft)), params: { post: { title: "The file" }, auto_save: true, destination: "link", day: 2.days.from_now.to_date.iso8601, hour: "7" }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_equal "The file", posts(:draft).reload.title
    assert posts(:draft).scheduled?
  end

  test "create from the editor schedules nothing when the save fails" do
    post post_schedule_path(posts(:draft)), params: { post: { title: "The file", visibility: "nowhere" }, auto_save: true, destination: "link", day: 2.days.from_now.to_date.iso8601, hour: "7" }

    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "Visibility", flash[:alert]
    assert_not posts(:draft).reload.scheduled?
    assert_equal "How to keep a contractor file", posts(:draft).title
  end

  test "create from the editor moves a scheduled post to another day and hour, and keeps where it goes" do
    day = 40.days.from_now.to_date

    post post_schedule_path(posts(:scheduled)), params: { destination: "web_and_email", day: day.iso8601, hour: "0" }

    assert_redirected_to edit_post_path(posts(:scheduled))
    assert_equal day.in_time_zone, posts(:scheduled).reload.scheduled_posting_at
    assert posts(:scheduled).scheduled_delivery?
  end

  test "create from the editor moves a scheduled post to another destination" do
    day = 40.days.from_now.to_date

    post post_schedule_path(posts(:scheduled)), params: { destination: "link", day: day.iso8601, hour: "0" }

    assert_redirected_to edit_post_path(posts(:scheduled))
    assert_equal day.in_time_zone, posts(:scheduled).reload.scheduled_posting_at
    assert_not posts(:scheduled).scheduled_delivery?
    assert posts(:scheduled).unlisted?

    post post_schedule_path(posts(:scheduled)), params: { destination: "email", day: day.iso8601, hour: "0" }
    assert posts(:scheduled).reload.scheduled_delivery?
    assert posts(:scheduled).email_only?
  end

  test "create from the editor with a time no longer ahead, or no day, schedules nothing and goes back to the editor with why" do
    post post_schedule_path(posts(:draft)), params: { destination: "link", day: 1.day.ago.to_date.iso8601, hour: "7", shown: shown_now }
    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "in the future", flash[:alert]

    post post_schedule_path(posts(:scheduled)), params: { destination: "web_and_email", day: 1.day.ago.to_date.iso8601, hour: "7" }
    assert_redirected_to edit_post_path(posts(:scheduled))
    assert_match "in the future", flash[:alert]
    assert posts(:scheduled).reload.scheduled_posting_at.future?

    post post_schedule_path(posts(:draft)), params: { destination: "link", day: "", hour: "7" }
    assert_redirected_to edit_post_path(posts(:draft))
    assert_match "in the future", flash[:alert]

    assert_not posts(:draft).reload.scheduled?
    assert posts(:draft).listed?
  end

  test "create from the editor that schedules nothing answers Turbo with a flash that says why, and the editor stays as it is" do
    post post_schedule_path(posts(:draft)), params: { destination: "web", day: 1.day.ago.to_date.iso8601, hour: "7" },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :unprocessable_entity
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream", count: 1
    assert_select "turbo-stream[action=replace][target=flash]"
    assert_includes response.body, "Pick a date and time in the future to schedule"
    assert_not_includes response.body, "post[title]"
    assert_not posts(:draft).reload.scheduled?
  end

  test "create from the editor refuses a draft an email it cannot send, and a destination that does not exist" do
    subscribers(:active).deactivate

    post post_schedule_path(posts(:draft)), params: { destination: "web_and_email", day: 2.days.from_now.to_date.iso8601, hour: "7" }
    assert_response :forbidden

    post post_schedule_path(posts(:draft)), params: { destination: "everywhere", day: 2.days.from_now.to_date.iso8601, hour: "7" }
    assert_response :forbidden
    assert_empty response.body

    assert_not posts(:draft).reload.scheduled?
    assert posts(:draft).listed?
  end

  test "create from a draft's editor left open on a post published since schedules and changes nothing" do
    post post_schedule_path(posts(:unlisted)), params: { post: { title: "An old draft" }, auto_save: true, destination: "web", day: 2.days.from_now.to_date.iso8601, hour: "7" }

    assert_redirected_to edit_post_path(posts(:unlisted))
    assert_match "published since", flash[:alert]
    assert_nil posts(:unlisted).reload.scheduled_posting_at
    assert_equal "Notes for the March workshop", posts(:unlisted).title
    assert posts(:unlisted).unlisted?
  end

  test "destroy cancels the schedule and leaves the draft" do
    delete post_schedule_path(posts(:scheduled))

    assert_redirected_to edit_post_path(posts(:scheduled))
    assert_not posts(:scheduled).reload.scheduled?
    assert posts(:scheduled).draft?
  end

  test "a post of another account is not found" do
    delete post_schedule_path(posts(:other_accounts))
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    post post_schedule_path(posts(:draft)), params: { scheduled_posting_at: 1.day.from_now.iso8601 }, as: :json

    assert_response :forbidden
    assert_not posts(:draft).reload.scheduled?

    post post_schedule_path(posts(:draft)), params: { post: { title: "No" }, destination: "web", day: 2.days.from_now.to_date.iso8601, hour: "7" }

    assert_response :forbidden
    assert_not posts(:draft).reload.scheduled?
    assert_not_equal "No", posts(:draft).title
  end

  private
    # What a draft's date is drawn as: the hour now running.
    def shown_now
      Time.zone.now.strftime("%Y-%m-%dT%H:00")
    end
end
