require "test_helper"

class Account::SubscribeFormsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the form to paste and the one form to save" do
    get edit_account_subscribe_form_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select "pre#subscribe-form-snippet", text: /#{Regexp.escape(public_embedded_subscription_path)}/
    assert_select "form[action=?]", account_subscribe_form_path, count: 1
    assert_select "input[type=url][name='account[subscription_return_url]'][placeholder='https://']"
  end

  test "update goes back to Settings" do
    patch account_subscribe_form_path, params: { account: { subscription_return_url: "https://newsletter.example/thanks" } }

    assert_redirected_to account_settings_path
    assert_equal "Settings saved", flash[:notice]
    assert_equal "https://newsletter.example/thanks", accounts(:davids_account).reload.subscription_return_url
  end

  test "update refuses a return address that is not https" do
    patch account_subscribe_form_path, params: { account: { subscription_return_url: "http://newsletter.example/thanks" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /The page to send people to must be a full address starting with https:\/\//
    assert_select "form[action=?]", account_subscribe_form_path
    assert_nil accounts(:davids_account).reload.subscription_return_url
  end

  test "update takes nothing else of the account" do
    patch account_subscribe_form_path, params: { account: { subscription_return_url: "https://newsletter.example/thanks", name: "The Bulletin", handle: "contractor-notes" } }

    assert_equal "Leo's Account", accounts(:davids_account).reload.name
    assert_nil accounts(:davids_account).handle
  end

  test "show as JSON has the return address" do
    get account_subscribe_form_path(format: :json)

    assert_response :success
    assert_equal({ "subscription_return_url" => nil }, response.parsed_body.to_h)
  end

  test "update as JSON answers with the return address" do
    patch account_subscribe_form_path, params: { subscription_return_url: "https://newsletter.example/thanks" }, as: :json

    assert_response :success
    assert_equal({ "subscription_return_url" => "https://newsletter.example/thanks" }, response.parsed_body.to_h)
    assert_equal "https://newsletter.example/thanks", accounts(:davids_account).reload.subscription_return_url
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_subscribe_form_path, params: { subscription_return_url: "http://newsletter.example/thanks" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["subscription_return_url"].present?
    assert_nil accounts(:davids_account).reload.subscription_return_url
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get edit_account_subscribe_form_path
    assert_response :forbidden

    patch account_subscribe_form_path, params: { account: { subscription_return_url: "https://mine.example/" } }
    assert_response :forbidden
    assert_nil accounts(:davids_account).reload.subscription_return_url
  end
end
