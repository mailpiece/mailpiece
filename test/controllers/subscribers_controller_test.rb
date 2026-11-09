require "test_helper"

class SubscribersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :mia
  end

  test "index lists the confirmed addresses" do
    get subscribers_path

    assert_response :success
    assert_match subscribers(:active).email, response.body
    assert_no_match subscribers(:unconfirmed).email, response.body
    assert_no_match subscribers(:bounced).email, response.body
  end

  test "index with no confirmed address counts who is waiting to confirm" do
    subscribers(:active).destroy!

    get subscribers_path

    assert_response :success
    assert_match "Nobody has confirmed yet", response.body
    assert_match "1 waiting to confirm", response.body
  end

  test "index with no subscriber at all offers to add some" do
    accounts(:davids_account).subscribers.destroy_all

    get subscribers_path

    assert_response :success
    assert_match "Add some", response.body
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
    assert_match "Stop sending", response.body
  end

  test "show offers to resume a stopped address" do
    get subscriber_path(subscribers(:stopped))

    assert_match "Resume sending", response.body
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

    assert_match edit_post_path(posts(:sent)), response.body
  end

  test "show never links to the referrer" do
    subscribers(:active).update!(referrer: "https://example.com/blog?ref=1")

    get subscriber_path(subscribers(:active))

    assert_no_match "example.com/blog", response.body
  end

  test "show for a bounced address says who stopped delivering and how the person returns" do
    get subscriber_path(subscribers(:bounced))

    assert_response :success
    assert_match "They can return by subscribing again.", response.body
    assert_no_match "Resume sending", response.body
    assert_no_match "Stop sending", response.body
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

  test "show lists no email of a journey for an address that was sent none" do
    get subscriber_path(subscribers(:bounced))

    assert_no_match "Welcome to the bulletin", response.body
  end

  test "show lists each email the person is in line for" do
    second = accounts(:davids_account).journey_emails.create!(trigger: "subscriber_confirmed", subject: "One more thing", body: "<p>Read the archive.</p>", active: true)
    second.deliveries.create!(subscriber: subscribers(:active), refused_at: Time.current)

    get subscriber_path(subscribers(:active))

    assert_match "Welcome to the bulletin", response.body
    assert_match "One more thing", response.body
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

    assert_match "Delete this subscriber", response.body
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
end
