require "test_helper"

class Users::EmailAddressesControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    sign_in_as :nonstaff
    @user = users(:nonstaff)
  end

  test "new" do
    get new_user_email_address_path(@user)

    assert_response :success
    assert_select "form input[name=?]", "email_address"
  end

  test "create mails a confirmation link and changes nothing yet" do
    assert_enqueued_emails 1 do
      post user_email_addresses_path(@user), params: { email_address: "newemail@example.com" }
    end

    assert_response :success
    assert_select "strong", text: "newemail@example.com"
    assert_equal "nonstaff@example.com", @user.reload.identity.email_address
  end

  test "create with an invalid email format" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: "notanemail" }
    end

    assert_redirected_to new_user_email_address_path(@user)
    assert_equal "Please enter a valid email address", flash[:alert]
  end

  test "create with the same email as the current one" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: @user.identity.email_address }
    end

    assert_redirected_to new_user_email_address_path(@user)
    assert_equal "That is already your email address", flash[:alert]
  end

  test "create with the email of another user in the same account" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: identities(:anlab).email_address }
    end

    assert_redirected_to new_user_email_address_path(@user)
    assert_equal "You already have a user in this account with that email address", flash[:alert]
  end

  test "create with an email that is only on another account" do
    assert_enqueued_emails 1 do
      post user_email_addresses_path(@user), params: { email_address: identities(:other_admin).email_address }
    end

    assert_response :success
  end

  test "another user's email is not found, for an admin too" do
    sign_in_as :mia

    get new_user_email_address_path(@user)
    assert_response :not_found

    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: "newemail@example.com" }
    end
    assert_response :not_found
  end

  test "create as JSON" do
    assert_enqueued_emails 1 do
      post user_email_addresses_path(@user), params: { email_address: "newemail@example.com" }, as: :json
    end

    assert_response :created
  end

  test "create as JSON with a blank email" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: "" }, as: :json
    end

    assert_response :bad_request
  end

  test "create as JSON with an invalid email format" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: "notanemail" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "Please enter a valid email address", @response.parsed_body["error"]
  end

  test "create as JSON with the same email in another case" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: @user.identity.email_address.upcase }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "That is already your email address", @response.parsed_body["error"]
  end

  test "create as JSON with the email of another user in the same account" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(@user), params: { email_address: identities(:anlab).email_address }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "You already have a user in this account with that email address", @response.parsed_body["error"]
  end

  test "create as JSON for another user" do
    assert_no_enqueued_emails do
      post user_email_addresses_path(users(:anlab)), params: { email_address: "newemail@example.com" }, as: :json
    end

    assert_response :not_found
  end
end
