require "test_helper"

class Users::EmailAddresses::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:nonstaff)
    @old_email = @user.identity.email_address
    @new_email = "newemail@example.com"
    @token = @user.send(:generate_email_address_change_token, to: @new_email)
  end

  test "show needs no session and changes nothing" do
    get user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token)

    assert_response :success
    assert_select "form input[name=?][value=?]", "email_address_token", @token
    assert_equal @old_email, @user.reload.identity.email_address
  end

  test "create changes the email and signs the new identity in" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token)

    assert_redirected_to user_url(script_name: @user.account.slug, id: @user)
    assert_equal @new_email, @user.reload.identity.email_address

    get user_path(@user)
    assert_response :success
  end

  test "create replaces the session of whoever was signed in" do
    sign_in_as :mia

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token)

    assert_equal @new_email, @user.reload.identity.email_address
    assert_equal "mia@example.com", users(:mia).reload.identity.email_address

    get user_path(@user)
    assert_response :success
  end

  test "create moves the user to the identity that already holds the address" do
    token = @user.send(:generate_email_address_change_token, to: identities(:other_admin).email_address)

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: token)

    assert_equal identities(:other_admin), @user.reload.identity
  end

  test "create with an invalid token" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid")

    assert_response :unprocessable_entity
    assert_match /Link expired/, response.body
    assert_select "a[href^=mailto]", count: 0
    assert_equal @old_email, @user.reload.identity.email_address
  end

  test "create with an invalid token offers help where there is an address to write to" do
    with_support_email_address "help@example.com" do
      post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid")

      assert_select "a[href=?]", "mailto:help@example.com", text: "send us an email"
    end
  end

  test "create with an expired token" do
    expired_token = @user.send(:generate_email_address_change_token, to: @new_email, expires_in: 30.minutes)

    travel_to 31.minutes.from_now do
      post user_email_address_confirmation_path(user_id: @user.id, email_address_token: expired_token)

      assert_response :unprocessable_entity
      assert_equal @old_email, @user.reload.identity.email_address
    end
  end

  test "create with a token used once already" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token)
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token)

    assert_response :unprocessable_entity
    assert_equal @new_email, @user.reload.identity.email_address
  end

  test "create with another user's token" do
    token = users(:anlab).send(:generate_email_address_change_token, to: @new_email)

    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: token)

    assert_response :unprocessable_entity
    assert_equal @old_email, @user.reload.identity.email_address
    assert_equal "anlab@example.com", users(:anlab).reload.identity.email_address
  end

  test "a user of another account is not found" do
    other = users(:other_admin)
    token = other.send(:generate_email_address_change_token, to: @new_email)

    post user_email_address_confirmation_path(user_id: other.id, email_address_token: token)

    assert_response :not_found
    assert_equal "other.admin@example.com", other.reload.identity.email_address
  end

  test "create as JSON" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: @token), as: :json

    assert_response :no_content
    assert_equal @new_email, @user.reload.identity.email_address
  end

  test "create as JSON with an invalid token" do
    post user_email_address_confirmation_path(user_id: @user.id, email_address_token: "invalid"), as: :json

    assert_response :unprocessable_entity
    assert_equal "Token is invalid or has expired", @response.parsed_body["error"]
    assert_equal @old_email, @user.reload.identity.email_address
  end
end
