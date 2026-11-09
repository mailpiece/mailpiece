require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "show" do
    get account_settings_path

    assert_response :success
  end

  test "show answers at the handle once it is picked" do
    accounts(:davids_account).update!(handle: "contractor-notes")

    get "/contractor-notes/account/settings"

    assert_response :success
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get account_settings_path

    assert_response :forbidden
  end
end
