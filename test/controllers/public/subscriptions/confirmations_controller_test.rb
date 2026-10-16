require "test_helper"

class Public::Subscriptions::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @subscriber = subscribers(:unconfirmed)
    @token = confirmation_token_for(@subscriber)
  end

  test "show offers the button and confirms nothing" do
    get public_subscription_confirmation_path(@token)

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "button", text: "Subscribe me"
    assert_select "form[action=?][method=post]", public_subscription_confirmation_path(@token)
    assert @subscriber.reload.unconfirmed?
  end

  test "create confirms" do
    post public_subscription_confirmation_path(@token)

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert @subscriber.reload.active?
  end

  test "create starts the journey for the person once" do
    assert_enqueued_jobs 1, only: Journey::DeliveryJob do
      post public_subscription_confirmation_path(@token)
      post public_subscription_confirmation_path(@token)
    end

    perform_enqueued_jobs only: Journey::DeliveryJob

    assert @subscriber.journey_deliveries.sole.sent_at?
    assert_equal [ @subscriber.email ], ActionMailer::Base.deliveries.last.to
    assert_equal "Welcome to the bulletin", ActionMailer::Base.deliveries.last.subject
  end

  test "a link that no longer works starts no journey" do
    @subscriber.unsubscribe

    assert_no_enqueued_jobs only: Journey::DeliveryJob do
      post public_subscription_confirmation_path(@token)
    end

    assert_empty @subscriber.journey_deliveries
  end

  test "the link in the email confirms" do
    perform_enqueued_jobs do
      post public_subscription_path, params: { email: "new@example.com" }
    end

    link = URI(ActionMailer::Base.deliveries.last.text_part.body.to_s[/\S+\/confirm$/]).request_uri

    get link
    assert_select "button", text: "Subscribe me"

    post link
    assert accounts(:davids_account).subscribers.find_by!(email: "new@example.com").active?
  end

  test "a used link no longer works" do
    post public_subscription_confirmation_path(@token)

    get public_subscription_confirmation_path(@token)
    assert_invalid_link

    assert_no_changes -> { @subscriber.reload.confirmed_at } do
      post public_subscription_confirmation_path(@token)
    end
    assert_invalid_link
  end

  test "an expired link no longer works" do
    travel Subscriber::CONFIRMATION_TOKEN_EXPIRATION + 1.minute

    get public_subscription_confirmation_path(@token)
    assert_invalid_link

    post public_subscription_confirmation_path(@token)
    assert_invalid_link
    assert @subscriber.reload.unconfirmed?
  end

  test "a link still works the day before it expires" do
    travel Subscriber::CONFIRMATION_TOKEN_EXPIRATION - 1.day

    post public_subscription_confirmation_path(@token)

    assert @subscriber.reload.active?
  end

  test "a link older than a newer confirmation no longer works" do
    @subscriber.update!(confirmations_count: 0)
    @subscriber.request_confirmation

    post public_subscription_confirmation_path(@token)
    assert_invalid_link
    assert @subscriber.reload.unconfirmed?

    post public_subscription_confirmation_path(confirmation_token_for(@subscriber))
    assert @subscriber.reload.active?
  end

  test "a link mailed before the unsubscribe no longer works" do
    @subscriber.unsubscribe

    get public_subscription_confirmation_path(@token)
    assert_invalid_link

    post public_subscription_confirmation_path(@token)
    assert_invalid_link
    assert @subscriber.reload.unsubscribed?
  end

  test "a link asked for after the unsubscribe confirms again" do
    post public_subscription_path, params: { email: subscribers(:unsubscribed).email }

    post public_subscription_confirmation_path(confirmation_token_for(subscribers(:unsubscribed)))

    assert subscribers(:unsubscribed).reload.active?
  end

  test "a link mailed before the bounce no longer works" do
    @subscriber.bounce

    post public_subscription_confirmation_path(@token)

    assert_invalid_link
    assert @subscriber.reload.bounced?
  end

  test "a link asked for after the bounce makes the address active again" do
    accounts(:davids_account).subscribers.subscribe(subscribers(:bounced).email)
    token = confirmation_token_for(subscribers(:bounced))

    get public_subscription_confirmation_path(token)
    assert_select "button", text: "Subscribe me"

    post public_subscription_confirmation_path(token)

    assert subscribers(:bounced).reload.active?
  end

  test "a link for an address stopped since no longer works" do
    @subscriber.deactivate

    post public_subscription_confirmation_path(@token)

    assert_invalid_link
    assert @subscriber.reload.deactivated?
    assert_nil @subscriber.confirmed_at
  end

  test "a link made for a stopped address does not resume it" do
    post public_subscription_confirmation_path(confirmation_token_for(subscribers(:stopped)))

    assert_invalid_link
    assert subscribers(:stopped).reload.deactivated?
  end

  test "a malformed token does not work" do
    get public_subscription_confirmation_path("nope")
    assert_invalid_link

    post public_subscription_confirmation_path("nope")
    assert_invalid_link
  end

  test "a signed token made for something else does not work" do
    post public_subscription_confirmation_path(@subscriber.to_sgid(for: "something_else").to_s)

    assert_invalid_link
    assert @subscriber.reload.unconfirmed?
  end

  test "another account's token does not work" do
    other = subscribers(:other_accounts)
    other.update!(confirmed_at: nil)

    post public_subscription_confirmation_path(confirmation_token_for(other))

    assert_invalid_link
    assert other.reload.unconfirmed?
  end

  test "the permanent token no longer confirms" do
    post public_subscription_confirmation_path(@subscriber.token)
    assert_invalid_link
    assert @subscriber.reload.unconfirmed?
  end

  test "the invalid link page says to subscribe again and promises no email" do
    get public_subscription_confirmation_path("nope")

    assert_select "p", text: /subscribe again from any post, or write to the newsletter/
    assert_select "button", text: "Subscribe me", count: 0
  end

  private
    def confirmation_token_for(subscriber)
      subscriber.reload.send(:generate_confirmation_token)
    end

    def assert_invalid_link
      assert_response :unprocessable_entity
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_select "h1", text: "This link no longer works"
    end
end
