require "test_helper"

class Account::DomainsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the one form, under Settings" do
    get edit_account_domain_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select "form[action=?]", account_domain_path, count: 1
    assert_select "input[name='account[domain]']"
  end

  test "update gives the newsletter a domain, changes it and clears it" do
    patch account_domain_path, params: { account: { domain: "Boletin.example" } }
    assert_redirected_to account_settings_path
    assert_equal "Settings saved", flash[:notice]
    assert_equal "boletin.example", accounts(:davids_account).reload.domain

    patch account_domain_path, params: { account: { domain: "news.boletin.example" } }
    assert_redirected_to account_settings_path
    assert_equal "news.boletin.example", accounts(:davids_account).reload.domain

    patch account_domain_path, params: { account: { domain: "" } }
    assert_redirected_to account_settings_path
    assert_nil accounts(:davids_account).reload.domain
  end

  test "update says what a domain is when it is refused" do
    patch account_domain_path, params: { account: { domain: "https://boletin.example/" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Domain must be a domain name alone/
    assert_select "form[action=?]", account_domain_path
    assert_nil accounts(:davids_account).reload.domain
  end

  test "update takes nothing else of the account" do
    patch account_domain_path, params: { account: { domain: "boletin.example", name: "The Bulletin", handle: "contractor-notes" } }

    assert_equal "Leo's Account", accounts(:davids_account).reload.name
    assert_nil accounts(:davids_account).handle
  end

  test "show as JSON has the domain, or none" do
    get account_domain_path(format: :json)

    assert_response :success
    assert_equal({ "domain" => nil }, response.parsed_body.to_h)

    accounts(:davids_account).update!(domain: "boletin.example")

    get account_domain_path(format: :json)
    assert_equal({ "domain" => "boletin.example" }, response.parsed_body.to_h)
  end

  test "update as JSON answers with the domain" do
    patch account_domain_path, params: { domain: "boletin.example" }, as: :json

    assert_response :success
    assert_equal({ "domain" => "boletin.example" }, response.parsed_body.to_h)
    assert_equal "boletin.example", accounts(:davids_account).reload.domain
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_domain_path, params: { domain: "https://boletin.example/" }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["domain"].present?
    assert_nil accounts(:davids_account).reload.domain
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get edit_account_domain_path
    assert_response :forbidden

    patch account_domain_path, params: { account: { domain: "mine.example" } }
    assert_response :forbidden
    assert_nil accounts(:davids_account).reload.domain
  end
end
