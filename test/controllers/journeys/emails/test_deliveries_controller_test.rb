require "test_helper"

class Journeys::Emails::TestDeliveriesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :mia
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @email = journey_emails(:davids)
  end

  test "create saves what is in the editor first, and sends a test to one's own address" do
    assert_enqueued_email_with JourneyMailer, :test_email, args: [ @email, "mia@example.com" ] do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "<p>Hello.</p>" } }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Test sent to mia@example.com", flash[:notice]
    assert_equal "Glad you came", @email.reload.subject
    assert_equal "Hello.", @email.body.to_plain_text
  end

  test "create sends the test to the address given" do
    assert_enqueued_email_with JourneyMailer, :test_email, args: [ @email, "editor@example.com" ] do
      post journey_email_test_delivery_path(@journey, @email), params: { email_address: " editor@example.com " }
    end

    assert_equal "Test sent to editor@example.com", flash[:notice]
  end

  test "create refuses an address that is not one" do
    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { email_address: "not an address" }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Enter a valid email address for the test", flash[:alert]
  end

  test "create as JSON sends the test and answers with nothing" do
    assert_enqueued_email_with JourneyMailer, :test_email, args: [ @email, "editor@example.com" ] do
      post journey_email_test_delivery_path(@journey, @email, format: :json), params: { email_address: "editor@example.com" }, as: :json
    end

    assert_response :created
    assert_empty response.body
  end

  test "create as JSON says what is wrong with the address" do
    post journey_email_test_delivery_path(@journey, @email, format: :json), params: { email_address: "not an address" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "Enter a valid email address for the test" ], response.parsed_body["base"]
  end

  test "create tests a draft, which stays one" do
    @email.deactivate

    assert_enqueued_emails 1 do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "Glad you came" }, auto_save: true }
    end

    assert_not @email.reload.active?
    assert_equal "Glad you came", @email.subject
  end

  test "create sends nothing when the save fails" do
    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "" } }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "The test was not sent. Message can't be blank", flash[:alert]
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "create sends nothing of a draft left blank, and saves it all the same" do
    @email.deactivate

    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "", body: "" }, auto_save: true }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Write the subject and the message before sending a test", flash[:alert]
    assert_not @email.reload.written?
  end

  test "create from a draft's editor left open on an email switched on since sends nothing" do
    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "An old draft" }, auto_save: true }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_match "switched on since", flash[:alert]
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "create without a complete sender sends nothing and says so" do
    account_senders(:davids).update!(from_address: nil)

    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "<p>Hello.</p>" } }
    end

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "The test was not sent. Email sending is not set up", flash[:alert]
  end

  test "create answers Turbo with the flash alone, so the editor stays as it is" do
    assert_enqueued_emails 1 do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "<p>Hello.</p>" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :success
    assert_select "turbo-stream", count: 1
    assert_select "turbo-stream[action=replace][target=flash]"
    assert_includes response.body, "Test sent to mia@example.com"
  end

  test "create that sends nothing answers Turbo with a flash too" do
    @email.deactivate

    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "", body: "" }, auto_save: true },
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_includes response.body, "Write the subject and the message before sending a test"
  end

  test "another account's email is not found" do
    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, journey_emails(:other_accounts))
    end

    assert_response :not_found
  end

  test "an email is found only through its own journey" do
    assert_no_enqueued_emails do
      post journey_email_test_delivery_path("subscriber_unsubscribed", @email)
    end

    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    assert_no_enqueued_emails do
      post journey_email_test_delivery_path(@journey, @email), params: { journey_email: { subject: "No", body: "<p>No.</p>" } }
    end

    assert_response :forbidden
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end
end
