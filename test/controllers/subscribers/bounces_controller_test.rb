require "test_helper"

class Subscribers::BouncesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "create marks the address bounced" do
    post subscriber_bounce_path(subscribers(:active))

    assert_redirected_to subscriber_path(subscribers(:active))
    assert subscribers(:active).reload.bounced?
  end

  test "create as JSON marks the address bounced and answers with nothing" do
    post subscriber_bounce_path(subscribers(:active), format: :json)

    assert_response :no_content
    assert subscribers(:active).reload.bounced?
  end

  test "create leaves an address already bounced as it was" do
    assert_no_changes -> { subscribers(:bounced).reload.bounced_at } do
      post subscriber_bounce_path(subscribers(:bounced), format: :json)
    end

    assert_response :no_content
  end

  test "another account's subscriber is not found" do
    post subscriber_bounce_path(subscribers(:other_accounts))

    assert_response :not_found
    assert subscribers(:other_accounts).reload.active?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    post subscriber_bounce_path(subscribers(:active))

    assert_response :forbidden
    assert subscribers(:active).reload.active?
  end

  test "the person subscribing again and confirming undoes the bounce" do
    post subscriber_bounce_path(subscribers(:active))

    post public_subscription_path, params: { email: subscribers(:active).email }
    post public_subscription_confirmation_path(subscribers(:active).reload.send(:generate_confirmation_token))

    assert subscribers(:active).reload.active?
  end
end
