require "test_helper"

class Subscribers::ActivationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "destroy stops sending" do
    delete subscriber_activation_path(subscribers(:active))

    assert_redirected_to subscriber_path(subscribers(:active))
    assert subscribers(:active).reload.deactivated?
  end

  test "create resumes sending" do
    post subscriber_activation_path(subscribers(:stopped))

    assert_redirected_to subscriber_path(subscribers(:stopped))
    assert subscribers(:stopped).reload.active?
  end

  test "create leaves an unsubscribed address unsubscribed" do
    post subscriber_activation_path(subscribers(:unsubscribed))

    assert subscribers(:unsubscribed).reload.unsubscribed?
  end

  test "destroy is refused for an unsubscribed or bounced address" do
    delete subscriber_activation_path(subscribers(:unsubscribed))
    assert_response :forbidden

    delete subscriber_activation_path(subscribers(:bounced))
    assert_response :forbidden
  end

  test "destroy as JSON says why an unsubscribed or bounced address is refused" do
    %i[ unsubscribed bounced ].each do |state|
      delete subscriber_activation_path(subscribers(state), format: :json)

      assert_response :forbidden
      assert_equal({ "error" => "Sending can't be stopped for an address that unsubscribed or bounced." }, response.parsed_body)
    end
  end

  test "destroy as JSON stops sending and answers with nothing" do
    delete subscriber_activation_path(subscribers(:active), format: :json)

    assert_response :no_content
    assert subscribers(:active).reload.deactivated?
  end

  test "create as JSON answers created only when it resumed sending" do
    post subscriber_activation_path(subscribers(:stopped), format: :json)
    assert_response :created
    assert_equal "confirmed", response.parsed_body["status"]

    post subscriber_activation_path(subscribers(:stopped), format: :json)
    assert_response :ok
    assert_equal "confirmed", response.parsed_body["status"]

    post subscriber_activation_path(subscribers(:unsubscribed), format: :json)
    assert_response :ok
    assert subscribers(:unsubscribed).reload.unsubscribed?
  end

  test "another account's subscriber is not found" do
    delete subscriber_activation_path(subscribers(:other_accounts))

    assert_response :not_found
    assert subscribers(:other_accounts).reload.active?
  end

  test "members are refused" do
    sign_in_as :nonstaff

    delete subscriber_activation_path(subscribers(:active))

    assert_response :forbidden
    assert subscribers(:active).reload.active?
  end
end
