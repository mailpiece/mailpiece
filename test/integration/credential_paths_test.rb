require "test_helper"

# Every route carrying a credential in its path is declared in config/routes.rb: a renamed route or
# parameter fails here rather than logging the credential.
class CredentialPathsTest < ActiveSupport::TestCase
  include FilterPathParameters::Assertions
  include Rails.application.routes.url_helpers

  setup do
    @slug = accounts(:davids_account).slug
  end

  test "a qr code's signed id is filtered" do
    assert_path_filtered qr_code_path("made-up-signed-id", script_name: @slug), "made-up-signed-id"
  end

  test "a join code is filtered" do
    assert_path_filtered join_path("made-up-code", script_name: @slug), "made-up-code"
  end

  test "a join code is filtered past the route" do
    assert_path_filtered "#{join_path("made-up-code", script_name: @slug)}/xmlrpc.php", "made-up-code"
  end

  test "an email address change token is filtered" do
    path = user_email_address_path("user-id", "made-up-token", script_name: @slug)

    assert_path_filtered path, "made-up-token"
  end

  test "an email address confirmation token is filtered" do
    path = user_email_address_confirmation_path("user-id", "made-up-token", script_name: @slug)

    assert_path_filtered path, "made-up-token"
  end

  test "a subscription confirmation token is filtered" do
    path = public_subscription_confirmation_path("made-up-token", script_name: @slug)

    assert_path_filtered path, "made-up-token"
  end

  test "an unsubscription token is filtered" do
    path = public_subscription_unsubscription_path("made-up-token", script_name: @slug)

    assert_path_filtered path, "made-up-token"
  end
end
