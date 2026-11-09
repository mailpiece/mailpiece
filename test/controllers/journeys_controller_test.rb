require "test_helper"

class JourneysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @email = journey_emails(:davids)
  end

  test "index lists each journey, leading to it" do
    get journeys_path

    assert_response :success
    assert_match journey_path(@journey), response.body
    assert_match journey_path("subscriber_unsubscribed"), response.body
    assert_no_match edit_journey_email_path(@journey, @email), response.body
    assert_no_match new_journey_email_path(@journey), response.body
  end

  test "index reads how each journey's runs stand in one query" do
    account = accounts(:davids_account)
    @journey.runs.create!(subscriber: subscribers(:unconfirmed))
    @journey.runs.create!(subscriber: subscribers(:unsubscribed), state: :left, ended_at: Time.current)
    @journey.runs.create!(subscriber: subscribers(:bounced), state: :refused, ended_at: Time.current)
    account.journey_triggered_by("subscriber_unsubscribed").runs.create!(subscriber: subscribers(:unsubscribed), state: :finished, ended_at: Time.current)
    Journey::Run.create!(subscriber: subscribers(:other_accounts), trigger: "subscriber_confirmed")

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "journey_runs"/) }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get journeys_path
    end

    assert_equal 1, queries.size
  end

  test "show lists the journey's own emails, and no other journey's or account's" do
    get journey_path(@journey)

    assert_response :success
    assert_match edit_journey_email_path(@journey, @email), response.body
    assert_match "Welcome to the bulletin", response.body
    assert_no_match "Sorry to see you go", response.body
    assert_no_match "Hello from elsewhere", response.body
    assert_no_match journey_emails(:other_accounts).to_param, response.body
  end

  test "show offers to delete each email" do
    get journey_path(@journey)

    assert_select "form[action=?] button", journey_email_path(@journey, @email), text: "Delete email"
  end

  test "show offers a new email only while the journey takes another" do
    get journey_path(@journey)
    assert_match new_journey_email_path(@journey), response.body

    get journey_path("subscriber_unsubscribed")
    assert_no_match new_journey_email_path("subscriber_unsubscribed"), response.body
  end

  test "show of a journey with no email still offers a new one" do
    journey_emails(:davids_goodbye).destroy!

    get journey_path("subscriber_unsubscribed")

    assert_response :success
    assert_match new_journey_email_path("subscriber_unsubscribed"), response.body
  end

  test "index as JSON lists each journey with its emails" do
    get journeys_path, as: :json

    assert_response :success
    assert_equal Journey::TRIGGERS, response.parsed_body.pluck("trigger")
    assert_equal [ [ @email.id ], [ journey_emails(:davids_goodbye).id ] ], response.parsed_body.map { it["emails"].pluck("id") }
  end

  test "show as JSON carries the journey's emails in the order they go" do
    later = @journey.emails.create!(subject: "A day in", body: "<p>Say <strong>hello</strong>.</p>", delay_days: 1)

    get journey_path(@journey, format: :json)

    assert_response :success
    assert_equal "subscriber_confirmed", response.parsed_body["trigger"]
    assert_equal [ @email.id, later.id ], response.parsed_body["emails"].pluck("id")

    email = response.parsed_body["emails"].last
    assert_equal "A day in", email["subject"]
    assert_equal "Say hello.", email["body"]
    assert_match "<strong>hello</strong>", email["body_html"]
    assert_equal 1, email["delay_days"]
    assert_nil email["send_hour"]
    assert_equal false, email["active"]
    assert_equal journey_email_url(@journey, later, format: :json), email["url"]
  end

  test "show as JSON of a journey that does not exist is not found" do
    get journey_path("card_closed", format: :json)

    assert_response :not_found
  end

  test "show of a journey that does not exist is not found" do
    get journey_path("card_closed")

    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get journeys_path
    assert_response :forbidden

    get journey_path(@journey)
    assert_response :forbidden
  end
end
