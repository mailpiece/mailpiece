require "test_helper"

class Public::Subscriptions::UnsubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "show offers the button and unsubscribes nobody" do
    get public_subscription_unsubscription_path(subscribers(:active).token)

    assert_response :success
    assert_select "button", text: "Unsubscribe"
    assert subscribers(:active).reload.active?
  end

  test "create unsubscribes in one click from a mail provider, with no forgery check" do
    with_forgery_protection do
      post public_subscription_unsubscription_path(subscribers(:active).token),
        params: { "List-Unsubscribe" => "One-Click" }, headers: { "Sec-Fetch-Site" => "cross-site" }
    end

    assert_response :ok
    assert subscribers(:active).reload.unsubscribed?
  end

  test "create starts the unsubscribe journey for the person once" do
    journey_emails(:davids_goodbye).activate

    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      2.times { post public_subscription_unsubscription_path(subscribers(:active).token) }
    end

    perform_enqueued_jobs only: Journey::DeliveryJob

    assert journey_emails(:davids_goodbye).deliveries.sole.sent_at?
    assert_equal [ subscribers(:active).email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Sorry to see you go", ActionMailer::Base.deliveries.last.subject
  end

  test "create twice keeps the first date" do
    with_forgery_protection do
      assert_no_changes -> { subscribers(:unsubscribed).reload.unsubscribed_at } do
        post public_subscription_unsubscription_path(subscribers(:unsubscribed).token), headers: { "Sec-Fetch-Site" => "cross-site" }
      end
    end

    assert_response :ok
  end

  test "a wrong token is not found" do
    post public_subscription_unsubscription_path("nope")
    assert_response :not_found
  end

  test "another account's token is not found" do
    post public_subscription_unsubscription_path(subscribers(:other_accounts).token)

    assert_response :not_found
    assert subscribers(:other_accounts).reload.active?
  end

  private
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
