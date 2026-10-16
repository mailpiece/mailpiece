require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "authenticate with valid access token" do
    untenanted { get my_identity_path(format: :json), env: api_token_env }

    assert_response :success
    assert_equal identities(:leo).id, @response.parsed_body["id"]
  end

  test "fail to authenticate with invalid access token" do
    untenanted { get my_identity_path(format: :json), env: bearer_token_env("nonsense") }

    assert_response :unauthorized
  end

  test "changing data requires a write-endowed access token" do
    untenanted do
      post my_access_tokens_path(format: :json), params: { access_token: { description: "CLI" } }, env: readonly_api_token_env
      assert_response :unauthorized

      post my_access_tokens_path(format: :json), params: { access_token: { description: "CLI" } }, env: api_token_env
      assert_response :created
    end
  end

  test "a read-only token reads an account and cannot write to it" do
    get subscribers_path(format: :json), env: readonly_api_token_env
    assert_response :success

    assert_no_difference -> { Subscriber.count } do
      post subscribers_path(format: :json), params: { subscriber: { email: "new@example.com" } }, env: readonly_api_token_env
    end
    assert_response :unauthorized
  end
end
