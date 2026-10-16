require "test_helper"

class Account::NewslettersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the one form, under Settings" do
    get edit_account_newsletter_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select "form[action=?]", account_newsletter_path, count: 1
    assert_select "input[name='account[name]'][value=?]", "Leo's Account"
    assert_select "input[type=file][name='account[avatar]']"
    assert_select "lexxy-editor[name='account[description]']"
  end

  test "update goes back to Settings" do
    patch account_newsletter_path, params: { account: { name: "The Bulletin", description: "<p>Notes on <strong>paperwork</strong>.</p>" } }

    assert_redirected_to account_settings_path
    assert_equal "Settings saved", flash[:notice]
    assert_equal "The Bulletin", accounts(:davids_account).reload.name
    assert_equal "Notes on paperwork.", accounts(:davids_account).description.to_plain_text
    assert_equal "Leo", account_senders(:davids).reload.from_name
  end

  test "update keeps the description short" do
    patch account_newsletter_path, params: { account: { description: "<p>#{"a" * 501}</p>" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation"
    assert_select "form[action=?]", account_newsletter_path
    assert accounts(:davids_account).reload.description.blank?
  end

  test "update refuses a blank name, and says it as the form does" do
    patch account_newsletter_path, params: { account: { name: " " } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Newsletter name/
    assert_equal "Leo's Account", accounts(:davids_account).reload.name
  end

  test "update with an image refused shows the logo that is stored and keeps what was typed" do
    accounts(:davids_account).avatar.attach io: file_fixture("moon.jpg").open, filename: "logo.jpg", content_type: "image/jpeg"

    patch account_newsletter_path, params: { account: { name: "The Bulletin", avatar: fixture_file_upload("subscribers.csv", "text/csv") } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation"
    assert_select "button[form=avatar-delete-form]"
    assert_select "form#avatar-delete-form[action=?]", account_avatar_path
    assert_select "input[name='account[name]'][value=?]", "The Bulletin"
    assert_equal "logo.jpg", accounts(:davids_account).reload.avatar.filename.to_s
  end

  test "update takes nothing else of the account" do
    patch account_newsletter_path, params: { account: { name: "The Bulletin", handle: "contractor-notes", external_account_id: 42, subscription_return_url: "https://newsletter.example/thanks" } }

    account = accounts(:davids_account).reload
    assert_equal "The Bulletin", account.name
    assert_nil account.handle
    assert_nil account.subscription_return_url
    assert_equal 1234567, account.external_account_id
  end

  test "update the welcome message" do
    patch account_newsletter_path, params: { account: { welcome_message: "<p>Paperwork, <strong>explained</strong>.</p>" } }

    assert_redirected_to account_settings_path
    assert_equal "Paperwork, explained.", accounts(:davids_account).reload.welcome_message.to_plain_text
    assert_equal "Leo's Account", accounts(:davids_account).name
  end

  test "update the welcome message via JSON" do
    patch account_newsletter_path, params: { welcome_message: "<p>Paperwork, <strong>explained</strong>.</p>" }, as: :json

    assert_response :success
    assert_equal "Paperwork, explained.", response.parsed_body["welcome_message"]
    assert_includes response.parsed_body["welcome_message_html"], "<strong>explained</strong>"
  end

  test "show as JSON has what the form edits" do
    get account_newsletter_path(format: :json)

    assert_response :success
    assert_equal %w[ name description description_html welcome_message welcome_message_html locale ], response.parsed_body.keys
    assert_equal "Leo's Account", response.parsed_body["name"]
    assert_equal "en", response.parsed_body["locale"]
  end

  test "show has no screen" do
    get account_newsletter_path

    assert_response :not_found
  end

  test "update as JSON answers with the newsletter" do
    patch account_newsletter_path, params: { name: "The Bulletin", description: "<p>Notes on <strong>paperwork</strong>.</p>", locale: "es" }, as: :json

    assert_response :success
    assert_equal "The Bulletin", response.parsed_body["name"]
    assert_equal "Notes on paperwork.", response.parsed_body["description"]
    assert_includes response.parsed_body["description_html"], "<strong>paperwork</strong>"
    assert_equal "es", response.parsed_body["locale"]
    assert_equal "The Bulletin", accounts(:davids_account).reload.name
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_newsletter_path, params: { name: " " }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["name"].present?
    assert_equal "Leo's Account", accounts(:davids_account).reload.name
  end

  test "a read-only token reads the newsletter and cannot change it" do
    tenanted_options = default_url_options
    reset!
    self.default_url_options = tenanted_options

    get account_newsletter_path(format: :json), env: readonly_api_token_env
    assert_response :success
    assert_equal "Leo's Account", response.parsed_body["name"]

    patch account_newsletter_path(format: :json), params: { account: { name: "The Bulletin" } }, env: readonly_api_token_env
    assert_response :unauthorized
    assert_equal "Leo's Account", accounts(:davids_account).reload.name

    patch account_newsletter_path(format: :json), params: { account: { name: "The Bulletin" } }, env: api_token_env
    assert_response :success
    assert_equal "The Bulletin", accounts(:davids_account).reload.name
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get edit_account_newsletter_path
    assert_response :forbidden

    patch account_newsletter_path, params: { account: { name: "Mine" } }
    assert_response :forbidden
    assert_equal "Leo's Account", accounts(:davids_account).reload.name
  end
end
