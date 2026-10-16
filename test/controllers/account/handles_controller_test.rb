require "test_helper"

class Account::HandlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "edit has the one form, under Settings" do
    get edit_account_handle_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", account_settings_path, text: "Settings"
    assert_select "form[action=?]", account_handle_path, count: 1
    assert_select "input[name='account[handle]']"
    assert_select "button[data-turbo-confirm]", count: 0
    assert_select "a[href=?]", numbered_url, count: 0
  end

  test "update gives the newsletter a handle and goes on to Settings at the new address" do
    patch account_handle_path, params: { account: { handle: "contractor-notes" } }

    assert_redirected_to "http://www.example.com/contractor-notes/account/settings"
    assert_equal "contractor-notes", accounts(:davids_account).reload.handle

    get "/contractor-notes/account/handle/edit"
    assert_response :success
    assert_select "form[action='/contractor-notes/account/handle']", count: 1
    assert_select "input[name='account[handle]'][value='contractor-notes']"
    assert_select "button[data-turbo-confirm=?]", "Change this address? Links already mailed with the old one stop working."
    assert_select "a[href=?]", numbered_url, text: numbered_url

    get "/#{accounts(:davids_account).external_account_id}/account/settings"
    assert_response :success
  end

  test "update changes a handle, and the old one stops answering and is free for another newsletter" do
    accounts(:davids_account).update!(handle: "contractor-notes")

    patch account_handle_path, params: { account: { handle: "another-name" } }
    assert_redirected_to "http://www.example.com/another-name/account/settings"
    assert_equal "another-name", accounts(:davids_account).reload.handle

    get "/another-name/account/settings"
    assert_response :success

    get "/contractor-notes/account/settings"
    assert_response :not_found

    accounts(:other_account).update!(handle: "contractor-notes")
    assert_equal "contractor-notes", accounts(:other_account).reload.handle
  end

  test "update clears a handle, and the newsletter answers at its number alone" do
    accounts(:davids_account).update!(handle: "contractor-notes")

    patch account_handle_path, params: { account: { handle: "" } }
    assert_redirected_to "http://www.example.com/#{accounts(:davids_account).external_account_id}/account/settings"
    assert_nil accounts(:davids_account).reload.handle

    get "/contractor-notes/account/settings"
    assert_response :not_found
  end

  test "update refuses a handle that is a screen of the app" do
    patch account_handle_path, params: { account: { handle: "posts" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /Name in the address is taken/
    assert_select "input[name='account[handle]']"
    assert_nil accounts(:davids_account).reload.handle
  end

  test "update says what a handle is made of when it is refused" do
    patch account_handle_path, params: { account: { handle: "Contractor Notes!" } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation", text: /lowercase letters, numbers and hyphens/
  end

  test "update takes nothing else of the account" do
    patch account_handle_path, params: { account: { handle: "contractor-notes", name: "The Bulletin" } }

    assert_equal "contractor-notes", accounts(:davids_account).reload.handle
    assert_equal "Leo's Account", accounts(:davids_account).name
  end

  test "show as JSON has the handle, or none" do
    get account_handle_path(format: :json)

    assert_response :success
    assert_equal({ "handle" => nil }, response.parsed_body.to_h)

    accounts(:davids_account).update!(handle: "contractor-notes")

    get "/contractor-notes/account/handle.json"
    assert_equal({ "handle" => "contractor-notes" }, response.parsed_body.to_h)
  end

  test "update as JSON answers with the handle" do
    patch account_handle_path, params: { handle: "contractor-notes" }, as: :json

    assert_response :success
    assert_equal({ "handle" => "contractor-notes" }, response.parsed_body.to_h)
    assert_equal "contractor-notes", accounts(:davids_account).reload.handle
  end

  test "update as JSON changes a handle already picked" do
    accounts(:davids_account).update!(handle: "contractor-notes")

    patch account_handle_path, params: { handle: "another-name" }, as: :json

    assert_response :success
    assert_equal({ "handle" => "another-name" }, response.parsed_body.to_h)
    assert_equal "another-name", accounts(:davids_account).reload.handle
  end

  test "update as JSON that does not save answers with the errors" do
    patch account_handle_path, params: { handle: "posts" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "is taken" ], response.parsed_body["handle"]
    assert_nil accounts(:davids_account).reload.handle
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get edit_account_handle_path
    assert_response :forbidden

    patch account_handle_path, params: { account: { handle: "mine" } }
    assert_response :forbidden
    assert_nil accounts(:davids_account).reload.handle
  end

  private
    def numbered_url
      "http://www.example.com#{accounts(:davids_account).numbered_slug}/"
    end
end
