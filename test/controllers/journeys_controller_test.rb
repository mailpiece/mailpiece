require "test_helper"

class JourneysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @email = journey_emails(:davids)
  end

  test "index lists each journey under Posts, as a row that leads to it" do
    get journeys_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", posts_path, text: "Posts"
    assert_select ".site-header__link[aria-current=page][href=?]", posts_path
    assert_select ".breadcrumbs strong", text: "Journeys"

    assert_select ".page ul.rows", count: 1
    assert_select "ul.rows li.row a.row__body .row__title" do |titles|
      assert_equal [ "When someone subscribes", "When someone unsubscribes" ], titles.map { it.text.strip }
    end
    assert_select "li.row a.row__body[href=?]", journey_path(@journey)
    assert_select "li.row a.row__body[href=?]", journey_path("subscriber_unsubscribed")
    assert_select ".status", count: 0
    assert_select "a[href=?]", edit_journey_email_path(@journey, @email), count: 0
    assert_select "a[href=?]", new_journey_email_path(@journey), count: 0
  end

  test "index says on each row how its runs stand, read in one query" do
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
    assert_select "li.row:first-child .row__meta", text: "1 in progress · 1 finished · 2 stopped early"
    assert_select "li.row:last-child .row__meta", text: "0 in progress · 1 finished · 0 stopped early"
  end

  test "index is written in the account's language" do
    accounts(:davids_account).update!(locale: "es")

    get journeys_path

    assert_equal [ "Cuando alguien se suscribe", "Cuando alguien se da de baja" ], css_select("li.row .row__title").map { it.text.strip }
    assert_select "li.row:first-child .row__meta", text: "0 en curso · 1 terminó · 0 se detuvieron antes"
  end

  test "show lists the journey's emails under Posts and Journeys" do
    get journey_path(@journey)

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", posts_path, text: "Posts"
    assert_select ".breadcrumbs a[href=?]", journeys_path, text: "Journeys"
    assert_select ".breadcrumbs strong", text: "When someone subscribes"
    assert_select ".site-header__link[aria-current=page][href=?]", posts_path

    assert_select ".page ul.rows li.row", count: 1 do
      assert_select "a.row__body[href=?] .row__title", edit_journey_email_path(@journey, @email), text: "Welcome to the bulletin"
      assert_select ".row__meta", text: "Sent at once"
      assert_select ".status", count: 0
    end

    assert_select "a[href*=?]", journey_emails(:davids_goodbye).to_param, count: 0
    assert_select "a[href*=?]", journey_emails(:other_accounts).to_param, count: 0
  end

  test "show says which of its emails is a draft" do
    get journey_path("subscriber_unsubscribed")

    assert_select ".page ul.rows li.row", count: 1 do
      assert_select "a.row__body[href=?] .row__title", edit_journey_email_path("subscriber_unsubscribed", journey_emails(:davids_goodbye)), text: "Sorry to see you go"
      assert_select ".row__meta", text: "Draft · Sent at once"
    end
  end

  test "show lists the emails by when they go, each saying so" do
    Time.use_zone("UTC") { @journey.emails.create!(subject: "The third morning", delay_days: 3, send_hour: 9) }
    @journey.emails.create!(subject: "A day in", delay_days: 1)
    @email.update!(delay_days: 2)

    get journey_path(@journey)

    assert_select ".page ul.rows li.row" do |rows|
      assert_equal [ "A day in", "Welcome to the bulletin", "The third morning" ], rows.map { it.at_css(".row__title").text.strip }
      assert_equal [ "Draft · 1 day later", "2 days later", "Draft · 3 days later · 09:00 UTC" ], rows.map { it.at_css(".row__meta").text.strip }
    end
  end

  test "show puts the trash on each row, and nothing to order them by hand" do
    get journey_path(@journey)

    assert_select "li##{dom_id(@email)} .step__actions form", count: 1
    assert_select "li##{dom_id(@email)} .step__actions form[action=?] button", journey_email_path(@journey, @email), text: "Delete email"
  end

  test "show offers a new email only while the journey takes another" do
    get journey_path(@journey)
    assert_select ".page a[href=?]", new_journey_email_path(@journey), text: "New email"

    get journey_path("subscriber_unsubscribed")
    assert_select "a[href=?]", new_journey_email_path("subscriber_unsubscribed"), count: 0
  end

  test "show of a journey with no email still offers a new one" do
    journey_emails(:davids_goodbye).destroy!

    get journey_path("subscriber_unsubscribed")

    assert_response :success
    assert_select ".page ul.rows", count: 0
    assert_select ".page a[href=?]", new_journey_email_path("subscriber_unsubscribed"), text: "New email"
  end

  test "show names an email with no subject" do
    @email.deactivate
    @email.update!(subject: "")

    get journey_path(@journey)

    assert_select "li##{dom_id(@email)} .row__title", text: "Untitled"
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
