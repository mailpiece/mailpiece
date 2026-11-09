require "test_helper"

class Journeys::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @journey = accounts(:davids_account).journey_triggered_by("subscriber_confirmed")
    @email = journey_emails(:davids)
  end

  test "new has the form, and nothing to switch the email on" do
    get new_journey_email_path(@journey)

    assert_response :success
    assert_select "form[action=?]", journey_emails_path(@journey), count: 1
    assert_select "[name='journey_email[active]']", count: 0
  end

  test "new and create are refused once the unsubscribe journey has its one email" do
    get new_journey_email_path("subscriber_unsubscribed")
    assert_response :forbidden

    assert_no_difference -> { Journey::Email.count } do
      post journey_emails_path("subscriber_unsubscribed"), params: { journey_email: { subject: "A second one" } }
    end
    assert_response :forbidden

    journey_emails(:davids_goodbye).destroy!

    get new_journey_email_path("subscriber_unsubscribed")
    assert_response :success
  end

  test "new and create of a journey that does not exist are not found" do
    get new_journey_email_path("card_closed")
    assert_response :not_found

    assert_no_difference -> { Journey::Email.count } do
      post journey_emails_path("card_closed"), params: { journey_email: { subject: "Hello" } }
    end
    assert_response :not_found
  end

  test "create writes a draft and opens its editor" do
    assert_difference -> { @journey.emails.count }, +1 do
      post journey_emails_path(@journey), params: { journey_email: { subject: "  Glad   you came ", body: "<p>Say <strong>hello</strong>.</p>" } }
    end

    email = @journey.emails.last
    assert_redirected_to edit_journey_email_path(@journey, email)
    assert_equal "Saved", flash[:notice]
    assert_equal "Glad you came", email.subject
    assert_equal "Say hello.", email.body.to_plain_text
    assert_equal "subscriber_confirmed", email.trigger
    assert_equal 0, email.delay_days
    assert email.draft?
  end

  test "create takes a blank email, and never one switched on, of another journey or of another account" do
    post journey_emails_path(@journey),
      params: { journey_email: { subject: "", active: "1", trigger: "subscriber_unsubscribed", account_id: accounts(:other_account).id } }

    email = @journey.emails.last
    assert email.draft?
    assert_equal [ journey_emails(:davids_goodbye) ], accounts(:davids_account).journey_triggered_by("subscriber_unsubscribed").emails.to_a
    assert_equal [ journey_emails(:other_accounts) ], accounts(:other_account).journey_emails.to_a
  end

  test "create as JSON answers with the draft" do
    assert_difference -> { @journey.emails.count }, +1 do
      post journey_emails_path(@journey), params: { subject: "Glad you came", body: "<p>Hello.</p>", delay_days: 2 }, as: :json
    end

    email = @journey.emails.last
    assert_response :created
    assert_equal journey_email_url(@journey, email, format: :json), response.location
    assert_equal email.id, response.parsed_body["id"]
    assert_equal "Glad you came", response.parsed_body["subject"]
    assert_equal "Hello.", response.parsed_body["body"]
    assert_equal 2, response.parsed_body["delay_days"]
    assert_equal false, response.parsed_body["active"]
  end

  test "create as JSON says what is wrong with the email" do
    assert_no_difference -> { Journey::Email.count } do
      post journey_emails_path(@journey), params: { subject: "Glad you came", delay_days: -1 }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["delay_days"].any?
  end

  test "create as JSON is refused once the unsubscribe journey has its one email" do
    assert_no_difference -> { Journey::Email.count } do
      post journey_emails_path("subscriber_unsubscribed"), params: { subject: "A second one" }, as: :json
    end

    assert_response :forbidden
  end

  test "edit of a draft offers to start sending it" do
    @email.deactivate

    get edit_journey_email_path(@journey, @email)

    assert_response :success
    assert_select "button[formaction=?]", journey_email_activation_path(@journey, @email), text: "Start sending"
    assert_no_match "Stop sending", response.body
    assert_select "button[formaction=?]", journey_email_path(@journey, @email), text: "Delete email"
    assert_select "[name='journey_email[active]']", count: 0
  end

  test "edit of an email switched on offers to stop sending it" do
    get edit_journey_email_path(@journey, @email)

    assert_response :success
    assert_select "button[formaction=?]", journey_email_activation_path(@journey, @email), text: "Stop sending"
    assert_no_match "Start sending", response.body
    assert_select "button[formaction=?]", journey_email_path(@journey, @email), text: "Delete email"
  end

  test "edit offers a test, whether or not the email is switched on" do
    get edit_journey_email_path(@journey, @email)
    assert_match journey_email_test_delivery_path(@journey, @email), response.body

    @email.deactivate
    get edit_journey_email_path(@journey, @email)
    assert_match journey_email_test_delivery_path(@journey, @email), response.body
  end

  test "edit without a complete sender offers no test, and says why" do
    account_senders(:davids).update!(from_address: nil)

    get edit_journey_email_path(@journey, @email)

    assert_no_match journey_email_test_delivery_path(@journey, @email), response.body
    assert_select "a[href=?]", edit_account_sender_path, text: "Finish the settings"
  end

  test "there is no page of an email's own" do
    get journey_email_path(@journey, @email)

    assert_response :not_found
  end

  test "show as JSON answers with the email, at the address its url gives" do
    get journey_email_path(@journey, @email, format: :json)

    assert_response :success
    assert_equal @email.id, response.parsed_body["id"]
    assert_equal @email.subject, response.parsed_body["subject"]
    assert_equal journey_email_url(@journey, @email, format: :json), response.parsed_body["url"]
  end

  test "body_html as JSON keeps an image attached when it is sent back" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("moon.jpg").open, filename: "moon.jpg", content_type: "image/jpeg")
    @email.update!(body: %(<p>Look.</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>))

    get journey_email_path(@journey, @email, format: :json)
    body_html = response.parsed_body["body_html"]

    assert_includes body_html, "action-text-attachment"
    assert_includes body_html, blob.attachable_sgid

    assert_no_enqueued_jobs only: ActiveStorage::PurgeJob do
      patch journey_email_path(@journey, @email, format: :json), params: { body: body_html }, as: :json
    end

    assert_response :success
    assert_includes @email.reload.body.body.attachables, blob
    assert ActiveStorage::Blob.exists?(blob.id)
  end

  test "update saves and stays in the editor" do
    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "  Glad   you came ", body: "<p>Say <strong>hello</strong>.</p>" } }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Saved", flash[:notice]
    assert_equal "Glad you came", @email.reload.subject
    assert_equal "Say hello.", @email.body.to_plain_text
    assert @email.active?
  end

  test "update never switches an email on or off, nor moves it to another journey or account" do
    patch journey_email_path(@journey, @email),
      params: { journey_email: { subject: "Hello", active: "0", trigger: "subscriber_unsubscribed", account_id: accounts(:other_account).id } }

    assert @email.reload.active?
    assert_equal "subscriber_confirmed", @email.trigger
    assert_equal accounts(:davids_account), @email.account
  end

  test "edit offers the delay, switched on or not" do
    get edit_journey_email_path(@journey, @email)
    assert_select "input[name='journey_email[delay_days]']", count: 1

    @email.deactivate
    get edit_journey_email_path(@journey, @email)
    assert_select "input[name='journey_email[delay_days]']", count: 1
  end

  test "edit of the unsubscribe journey's email offers no delay, and update takes none" do
    goodbye = journey_emails(:davids_goodbye)

    get edit_journey_email_path("subscriber_unsubscribed", goodbye)

    assert_response :success
    assert_select "input[name='journey_email[delay_days]']", count: 0

    patch journey_email_path("subscriber_unsubscribed", goodbye), params: { journey_email: { subject: "Goodbye", delay_days: "4" } }

    assert_equal "Goodbye", goodbye.reload.subject
    assert_equal 0, goodbye.delay_days
  end

  test "update saves the delay" do
    patch journey_email_path(@journey, @email), params: { journey_email: { delay_days: "3" } }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal 3, @email.reload.delay_days
  end

  test "update refuses a delay that is negative or not a number, and shows the editor again" do
    [ "-1", "soon", "1.5" ].each do |delay|
      patch journey_email_path(@journey, @email), params: { journey_email: { delay_days: delay } }

      assert_response :unprocessable_entity
      assert_match(/Days after subscribing (must|is)/, response.body)
      assert_equal 0, @email.reload.delay_days
    end
  end

  test "an email is found only through its own journey" do
    get edit_journey_email_path("subscriber_unsubscribed", @email)
    assert_response :not_found

    patch journey_email_path("subscriber_unsubscribed", @email), params: { journey_email: { subject: "Mine" } }
    assert_response :not_found
    assert_equal "Welcome to the bulletin", @email.reload.subject

    get edit_journey_email_path("card_closed", @email)
    assert_response :not_found
  end

  test "update of an email switched on with one of the two left blank shows the editor again" do
    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "Hello", body: "" } }

    assert_response :unprocessable_entity
    assert_match "Message can&#39;t be blank", response.body
    assert_equal "Welcome to the bulletin", @email.reload.subject

    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "", body: "<p>Hello.</p>" } }

    assert_response :unprocessable_entity
    assert_match "Subject can&#39;t be blank", response.body
  end

  test "update from Save draft takes a blank draft and stays in the editor" do
    @email.deactivate

    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "", body: "" }, auto_save: true }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_equal "Saved", flash[:notice]
    assert_not @email.reload.written?
  end

  test "update as JSON answers with the email" do
    patch journey_email_path(@journey, @email, format: :json), params: { subject: "Glad you came", delay_days: 3 }, as: :json

    assert_response :success
    assert_equal "Glad you came", response.parsed_body["subject"]
    assert_equal 3, response.parsed_body["delay_days"]
    assert_equal true, response.parsed_body["active"]
    assert_equal "Glad you came", @email.reload.subject
  end

  test "update as JSON says what is wrong with the email" do
    patch journey_email_path(@journey, @email, format: :json), params: { subject: "" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], response.parsed_body["subject"]
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "auto-save writes a draft" do
    @email.deactivate

    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "The hello" }, auto_save: true }, as: :json

    assert_response :success
    assert_equal "The hello", @email.reload.subject
  end

  test "auto-save onto an email switched on is refused" do
    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "The hello" }, auto_save: true }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "update from a draft's editor left open on an email switched on since changes nothing" do
    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "An old draft" }, auto_save: true }

    assert_redirected_to edit_journey_email_path(@journey, @email)
    assert_match "switched on since", flash[:alert]
    assert_equal "Welcome to the bulletin", @email.reload.subject
  end

  test "destroy deletes the email with its deliveries and goes back to the list" do
    assert_difference -> { Journey::Email.count } => -1, -> { Journey::Delivery.count } => -1 do
      delete journey_email_path(@journey, @email)
    end

    assert_redirected_to journey_path(@journey)
    assert_equal "Email deleted", flash[:notice]
  end

  test "destroy as JSON answers with no content" do
    delete journey_email_path(@journey, @email, format: :json)

    assert_response :no_content
    assert_not Journey::Email.exists?(@email.id)
  end

  test "another account's email is not found" do
    get edit_journey_email_path(@journey, journey_emails(:other_accounts))
    assert_response :not_found

    get journey_email_path(@journey, journey_emails(:other_accounts), format: :json)
    assert_response :not_found

    patch journey_email_path(@journey, journey_emails(:other_accounts)), params: { journey_email: { subject: "Mine" } }
    assert_response :not_found
    assert_equal "Hello from elsewhere", journey_emails(:other_accounts).reload.subject

    assert_no_difference -> { Journey::Email.count } do
      delete journey_email_path(@journey, journey_emails(:other_accounts))
    end
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get new_journey_email_path(@journey)
    assert_response :forbidden

    get edit_journey_email_path(@journey, @email)
    assert_response :forbidden

    patch journey_email_path(@journey, @email), params: { journey_email: { subject: "Mine" } }
    assert_response :forbidden
    assert_equal "Welcome to the bulletin", @email.reload.subject

    assert_no_difference -> { Journey::Email.count } do
      delete journey_email_path(@journey, @email)
    end
    assert_response :forbidden
  end
end
