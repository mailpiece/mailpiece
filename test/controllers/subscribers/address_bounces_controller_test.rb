require "test_helper"

class Subscribers::AddressBouncesControllerTest < ActionDispatch::IntegrationTest
  test "create marks the address bounced, written however the provider writes it" do
    post subscribers_bounces_path(format: :json), params: { email_address: "  #{subscribers(:active).email.upcase} " }, as: :json, env: api_token_env

    assert_response :no_content
    assert subscribers(:active).reload.bounced?
  end

  test "create leaves an address already bounced as it was" do
    assert_no_changes -> { subscribers(:bounced).reload.bounced_at } do
      post subscribers_bounces_path(format: :json), params: { email_address: subscribers(:bounced).email }, as: :json, env: api_token_env
    end

    assert_response :no_content
  end

  test "an address no subscriber has is not found, and no row is written" do
    assert_no_difference -> { Subscriber.count } do
      post subscribers_bounces_path(format: :json), params: { email_address: "nobody@example.com" }, as: :json, env: api_token_env
    end

    assert_response :not_found
  end

  test "create marks only this account's subscriber with the address" do
    assert_equal subscribers(:active).email, subscribers(:other_accounts).email

    post subscribers_bounces_path(format: :json), params: { email_address: subscribers(:active).email }, as: :json, env: api_token_env

    assert subscribers(:active).reload.bounced?
    assert subscribers(:other_accounts).reload.active?
  end

  test "a read-only token is refused" do
    post subscribers_bounces_path(format: :json), params: { email_address: subscribers(:active).email }, as: :json, env: readonly_api_token_env

    assert_response :unauthorized
    assert subscribers(:active).reload.active?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    post subscribers_bounces_path(format: :json), params: { email_address: subscribers(:active).email }, as: :json

    assert_response :forbidden
    assert subscribers(:active).reload.active?
  end

  test "the person subscribing again and confirming undoes the bounce" do
    post subscribers_bounces_path(format: :json), params: { email_address: subscribers(:active).email }, as: :json, env: api_token_env

    post public_subscription_path, params: { email: subscribers(:active).email }
    post public_subscription_confirmation_path(subscribers(:active).reload.send(:generate_confirmation_token))

    assert subscribers(:active).reload.active?
  end
end
