require "test_helper"

class Journeys::Emails::ActivationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @email = journey_emails(:davids)
  end

  test "create saves what is in the editor first, and switches the email on" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "<p>Hello.</p>" }, auto_save: true }

    assert_redirected_to journey_path(@journey)
    assert_equal "This email is now sent", flash[:notice]
    assert @email.reload.active?
    assert_equal "Glad you came", @email.subject
    assert_equal "Hello.", @email.body.to_plain_text
  end

  test "create switches the email on as it is, with none of its fields" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email)

    assert_redirected_to journey_path(@journey)
    assert @email.reload.active?
  end

  test "create does nothing to an email already switched on" do
    post journey_email_activation_path(@journey, @email)

    assert_redirected_to journey_path(@journey)
    assert @email.reload.active?
  end

  test "create keeps an email with no subject or no body off, saves it all the same and says why" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), params: { journey_email: { subject: "Glad you came", body: "" }, auto_save: true }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Message can't be blank", flash[:alert]
    assert_not @email.reload.active?
    assert_equal "Glad you came", @email.subject
  end

  test "create that is refused answers Turbo with the flash alone, so the editor stays as it is" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), params: { journey_email: { subject: "", body: "<p>Hello.</p>" }, auto_save: true },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=flash]", count: 1
    assert_match(/Subject can.+t be blank/, response.body)
    assert_not @email.reload.active?
  end

  test "create from a draft's editor left open on an email switched on since changes nothing" do
    post journey_email_activation_path(@journey, @email), params: { journey_email: { subject: "An old draft" }, auto_save: true }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_match "switched on since", flash[:alert]
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "destroy switches the email off and keeps what was written" do
    2.times { delete journey_email_activation_path(@journey, @email) }

    assert_redirected_to journey_path(@journey)
    assert_equal "This email is no longer sent", flash[:notice]
    assert_not @email.reload.active?
    assert @email.written?
  end

  test "destroy takes none of the editor's text" do
    delete journey_email_activation_path(@journey, @email), params: { journey_email: { subject: "Unsaved" } }

    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "create as JSON answers with the email switched on" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), as: :json

    assert_response :created
    assert_equal @email.id, response.parsed_body["id"]
    assert_equal true, response.parsed_body["active"]
    assert @email.reload.active?
  end

  test "create as JSON saves the fields sent with it, and switches the email on" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), params: { subject: "Glad you came", delay_days: 2 }, as: :json

    assert_response :created
    assert_equal "Glad you came", @email.reload.subject
    assert_equal 2, @email.delay_days
    assert @email.active?
  end

  test "create as JSON says why an email stays off" do
    goodbye = journey_emails(:davids_goodbye)
    goodbye.update!(subject: "")

    post journey_email_activation_path("subscriber_unsubscribed", goodbye), as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], response.parsed_body["subject"]
    assert_not goodbye.reload.active?
  end

  test "destroy as JSON switches the email off and answers with nothing" do
    delete journey_email_activation_path(@journey, @email, format: :json)

    assert_response :no_content
    assert_not @email.reload.active?
  end

  test "create takes the delay with the text where the journey has one, and nowhere else" do
    @email.deactivate

    post journey_email_activation_path(@journey, @email), params: { journey_email: { delay_days: "2" }, auto_save: true }
    assert_equal 2, @email.reload.delay_days

    post journey_email_activation_path("subscriber_unsubscribed", journey_emails(:davids_goodbye)), params: { journey_email: { delay_days: "2" }, auto_save: true }
    assert journey_emails(:davids_goodbye).reload.active?
    assert_equal 0, journey_emails(:davids_goodbye).delay_days
  end

  test "another account's email is not found" do
    post journey_email_activation_path(@journey, journey_emails(:other_accounts))

    assert_response :not_found
    assert_not journey_emails(:other_accounts).reload.active?
  end

  test "an email is found only through its own journey, and an unknown journey is not found" do
    @email.deactivate

    post journey_email_activation_path("subscriber_unsubscribed", @email)
    assert_response :not_found

    post journey_email_activation_path("card_closed", @email)
    assert_response :not_found

    assert_not @email.reload.active?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    delete journey_email_activation_path(@journey, @email)

    assert_response :forbidden
    assert @email.reload.active?
  end
end
