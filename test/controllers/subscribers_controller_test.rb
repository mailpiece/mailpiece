require "test_helper"

class SubscribersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :mia
  end

  test "index" do
    get subscribers_path

    assert_response :success
    assert_select "li.row:has(a[href=?]) .row__end", subscribers_active_path, text: accounts(:davids_account).subscribers.active.count.to_s
  end

  test "index counts each state, the confirmed first, each on a screen of its own" do
    get subscribers_path

    assert_select "ul.rows--links li.row:first-child a[href=?]", subscribers_active_path, text: "Confirmed"
    assert_select "li##{dom_id(subscribers(:active))}", count: 0
    assert_select "li.row:has(a[href=?]) .row__end", subscribers_deactivated_path, text: "1"
    assert_select "li.row:has(a[href=?]) .row__end", subscribers_bounced_path, text: "1"
    assert_select "h2.rows__heading", count: 0
  end

  test "index offers to search everyone for what the filter did not find on the screen" do
    get subscribers_path

    assert_select ".filter__empty a[href=?][data-quick-find-target=searchLink]", search_path
  end

  test "index as JSON lists who the screen lists and never exposes the token" do
    get subscribers_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).subscribers.active.ids.sort, response.parsed_body.pluck("id").sort
    assert response.parsed_body.none? { |subscriber| subscriber.key?("token") }
  end

  test "index invalidates its cache when an address it only counts changes" do
    get subscribers_path
    etag = response.headers["ETag"]

    subscribers(:bounced).destroy!

    get subscribers_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "index invalidates its cache when the account in its header is renamed" do
    get subscribers_path
    etag = response.headers["ETag"]

    accounts(:davids_account).update!(name: "Renamed")

    get subscribers_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "show" do
    get subscriber_path(subscribers(:active))

    assert_response :success
    assert_select "button", text: "Stop sending"
  end

  test "show resumes a stopped address without asking" do
    get subscriber_path(subscribers(:stopped))

    assert_select "form[action=?] button:not([data-turbo-confirm])", subscriber_activation_path(subscribers(:stopped)), text: "Resume sending"
  end

  test "show as JSON says where the address came from" do
    subscribers(:active).update!(source_post: posts(:sent), referrer: "https://example.com/blog")

    get subscriber_path(subscribers(:active)), as: :json

    assert_equal posts(:sent).code, response.parsed_body.dig("source_post", "code")
    assert_equal posts(:sent).title, response.parsed_body.dig("source_post", "title")
    assert_equal "https://example.com/blog", response.parsed_body["referrer"]
  end

  test "show lists the posts mailed to the address in the history, each linked to its post" do
    get subscriber_path(subscribers(:active))

    assert_select "a.trail__sentence--link[href=?]", edit_post_path(posts(:sent)), text: "“#{posts(:sent).title}” sent", count: 1
    assert_select "ul.rows", count: 0
  end

  test "show says in the history which post the address subscribed from, linked to it" do
    subscribers(:active).update!(source_post: posts(:sent), referrer: "https://example.com/blog")

    get subscriber_path(subscribers(:active))

    assert_select "a.trail__sentence--link[href=?]", edit_post_path(posts(:sent)), text: "Subscribed from “#{posts(:sent).title}”"
  end

  test "show names the referrer's host in the history, never as a link" do
    subscribers(:active).update!(referrer: "https://example.com/blog?ref=1")

    get subscriber_path(subscribers(:active))

    assert_select "span.trail__sentence", text: "Subscribed from example.com"
    assert_select "a[href*='example.com/blog']", count: 0
  end

  test "show says plain Subscribed when where from is not known" do
    get subscriber_path(subscribers(:active))

    assert_select ".trail__sentence", text: "Subscribed"
  end

  test "show for a bounced address says who stopped delivering and how the person returns" do
    get subscriber_path(subscribers(:bounced))

    assert_response :success
    assert_select ".record__title", text: "cleo@example.com"
    assert_select ".record__byline .status--badge", text: /bounced/i
    assert_select ".record__byline", text: /The mail server stopped delivering to this address on .*They can return by subscribing again\./m
    assert_select ".trail__sentence", text: "Bounced: the mail server stopped delivering to this address"
    assert_select "button", text: "Resume sending", count: 0
    assert_select "button", text: "Stop sending", count: 0
  end

  test "show as JSON lists the posts sent to the address" do
    get subscriber_path(subscribers(:active)), as: :json

    assert_response :success
    assert_equal "confirmed", response.parsed_body["status"]
    assert_nil response.parsed_body["source_post"]
    assert_nil response.parsed_body["referrer"]
    assert_equal [ posts(:sent).title ], response.parsed_body["deliveries"].map { |delivery| delivery.dig("post", "title") }
    assert_equal "sent", response.parsed_body["deliveries"].first["status"]
    assert_equal subscribers(:active).deliveries.sole.id, response.parsed_body["deliveries"].first["id"]
    assert_equal subscribers(:active).deliveries.sole.created_at.utc.as_json, response.parsed_body["deliveries"].first["created_at"]
  end

  test "show names the journey's email in the history, in the state it is in" do
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“Welcome to the bulletin” sent"

    journey_deliveries(:sent_to_active).update!(sent_at: nil, refused_at: Time.current)
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“Welcome to the bulletin” refused by the mail server"

    journey_deliveries(:sent_to_active).update!(refused_at: nil, claimed_at: 10.minutes.ago)
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“Welcome to the bulletin” unverified: it may or may not have arrived"

    journey_deliveries(:sent_to_active).update!(claimed_at: nil)
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“Welcome to the bulletin” waiting to be sent"
  end

  test "show lists no email of a journey for an address that was sent none" do
    get subscriber_path(subscribers(:bounced))

    assert_select ".trail__sentence", text: /“/, count: 0
  end

  test "show lists one entry for each email the person is in line for, under its own subject" do
    second = accounts(:davids_account).journey_emails.create!(trigger: "subscriber_confirmed", subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    second.deliveries.create!(subscriber: subscribers(:active), refused_at: Time.current)
    untitled = accounts(:davids_account).journey_emails.create!(trigger: "subscriber_confirmed")
    untitled.deliveries.create!(subscriber: subscribers(:active), deliver_at: 3.days.from_now)

    get subscriber_path(subscribers(:active))

    assert_select ".trail__sentence", text: "“Welcome to the bulletin” sent", count: 1
    assert_select ".trail__sentence", text: "“One more thing” refused by the mail server", count: 1
    assert_select ".trail__sentence", text: "“Untitled” waiting to be sent", count: 1
  end

  test "show says in the history how a journey ended, and nothing of one still in progress" do
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“When someone subscribes” journey finished", count: 1

    journey_runs(:active_confirmed).left!
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“When someone subscribes” journey stopped: their status changed", count: 1

    journey_runs(:active_confirmed).refused!
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: "“When someone subscribes” journey stopped: the mail server refused an email", count: 1

    journey_runs(:active_confirmed).update!(state: :in_progress, ended_at: nil)
    get subscriber_path(subscribers(:active))
    assert_select ".trail__sentence", text: /journey (finished|stopped)/, count: 0
  end

  test "show loads the emails of the history in one query, however many there are" do
    3.times do |number|
      accounts(:davids_account).journey_emails.create!(trigger: "subscriber_confirmed", subject: "Email #{number}")
        .deliveries.create!(subscriber: subscribers(:active))
    end

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM "journey_emails"/) }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get subscriber_path(subscribers(:active))
    end

    assert_equal 1, queries.size
  end

  test "create adds the address confirmed, with no mail" do
    assert_no_enqueued_emails do
      post subscribers_path, params: { email: "new@example.com", unsubscribed_at: Time.current }, as: :json
    end

    assert_response :created
    assert_equal "confirmed", response.parsed_body["status"]
  end

  test "create confirms an unconfirmed address" do
    post subscribers_path, params: { email: subscribers(:unconfirmed).email }, as: :json

    assert_response :ok
    assert subscribers(:unconfirmed).reload.active?
  end

  test "create never brings back an unsubscribed, bounced or stopped address, and says which it is" do
    refusals = {
      unsubscribed: "unsubscribed, and only they can subscribe again",
      bounced: "bounced, and only they can subscribe again",
      stopped: "was stopped by an admin, and is resumed from its own page"
    }

    refusals.each do |state, refusal|
      assert_no_changes -> { subscribers(state).reload.status } do
        post subscribers_path, params: { email: subscribers(state).email }, as: :json
      end

      assert_response :unprocessable_entity
      assert_equal({ "email" => [ refusal ] }, response.parsed_body)
    end
  end

  test "create as JSON with an invalid address says so" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_path, params: { email: "not an address" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal({ "email" => [ "isn't an email address" ] }, response.parsed_body)
  end

  test "create with an invalid address" do
    post subscribers_path, params: { subscriber: { email: "not an address" } }

    assert_redirected_to subscribers_path
    assert_match "wasn't added", flash[:alert]
  end

  test "another account's subscriber is not found" do
    get subscriber_path(subscribers(:other_accounts))
    assert_response :not_found
  end

  test "show has the button to delete the subscriber" do
    get subscriber_path(subscribers(:unsubscribed))

    assert_select "form[action=?]:has(input[name=_method][value=delete]) button[data-turbo-confirm=?]", subscriber_path(subscribers(:unsubscribed)),
      "Permanently delete dan@example.com? Its history goes with it, and nothing will remember whether it unsubscribed or bounced.",
      text: "Delete this subscriber"
  end

  test "destroy deletes the subscriber and goes back to the list" do
    assert_difference -> { accounts(:davids_account).subscribers.count }, -1 do
      delete subscriber_path(subscribers(:active))
    end

    assert_redirected_to subscribers_path
    assert_equal "ada@example.com was deleted.", flash[:notice]
    assert_not Subscriber.exists?(subscribers(:active).id)
  end

  test "destroy as JSON answers with no content" do
    delete subscriber_path(subscribers(:active), format: :json)

    assert_response :no_content
    assert_not Subscriber.exists?(subscribers(:active).id)
  end

  test "destroy of another account's subscriber is not found" do
    assert_no_difference -> { Subscriber.count } do
      delete subscriber_path(subscribers(:other_accounts))
    end

    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get subscribers_path
    assert_response :forbidden

    assert_no_difference -> { Subscriber.count } do
      delete subscriber_path(subscribers(:active))
    end
    assert_response :forbidden

    assert_no_difference -> { Subscriber.count } do
      post subscribers_path, params: { subscriber: { email: "new@example.com" } }
    end
    assert_response :forbidden
  end

  private
    def dom_id(record)
      ActionView::RecordIdentifier.dom_id(record)
    end
end
