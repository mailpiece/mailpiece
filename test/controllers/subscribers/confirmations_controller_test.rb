require "test_helper"

class Subscribers::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create confirms an unconfirmed address and starts its journey" do
    post subscriber_confirmation_path(subscribers(:unconfirmed))

    assert_redirected_to subscriber_path(subscribers(:unconfirmed))
    assert subscribers(:unconfirmed).reload.active?
    assert_equal [ "subscriber_confirmed" ], subscribers(:unconfirmed).journey_runs.map(&:trigger)
  end

  test "create refuses an unsubscribed or bounced address and leaves it where it is" do
    post subscriber_confirmation_path(subscribers(:unsubscribed))
    assert_response :forbidden

    post subscriber_confirmation_path(subscribers(:bounced))
    assert_response :forbidden

    assert subscribers(:unsubscribed).reload.unsubscribed?
    assert subscribers(:bounced).reload.bounced?
    assert_empty subscribers(:unsubscribed).journey_runs
    assert_empty subscribers(:bounced).journey_runs
  end

  test "create as JSON confirms once, and refuses an address already confirmed" do
    post subscriber_confirmation_path(subscribers(:unconfirmed), format: :json)
    assert_response :created
    assert_equal "confirmed", response.parsed_body["status"]

    post subscriber_confirmation_path(subscribers(:unconfirmed), format: :json)
    assert_response :forbidden
    assert_equal "Only an address that never confirmed can be confirmed here. Someone who unsubscribed or bounced subscribes again themselves.", response.parsed_body["error"]
  end

  test "another account's subscriber is not found" do
    post subscriber_confirmation_path(subscribers(:other_accounts))

    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    post subscriber_confirmation_path(subscribers(:unconfirmed))

    assert_response :forbidden
    assert subscribers(:unconfirmed).reload.unconfirmed?
  end
end
