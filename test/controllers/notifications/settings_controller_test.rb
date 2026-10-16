require "test_helper"

class Notifications::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @settings = users(:mia).settings
  end

  test "show" do
    get notifications_settings_path

    assert_response :success
    assert_select "form[action=?] input[type=checkbox][name=?][checked]", notifications_settings_path, "user_settings[new_subscriber_notifications]"
    assert_select ".site-header__link[aria-current=page][href=?]", account_settings_path, text: /Settings/
  end

  test "show as JSON" do
    get notifications_settings_path, as: :json

    assert_response :success
    assert_equal true, response.parsed_body["new_subscriber_notifications"]
  end

  test "update switches the new subscriber emails off and on" do
    patch notifications_settings_path, params: { user_settings: { new_subscriber_notifications: "0" } }

    assert_redirected_to notifications_settings_path
    assert_not @settings.reload.new_subscriber_notifications?

    get notifications_settings_path
    assert_select "input[type=checkbox][name=?]:not([checked])", "user_settings[new_subscriber_notifications]"

    patch notifications_settings_path, params: { user_settings: { new_subscriber_notifications: "1" } }
    assert @settings.reload.new_subscriber_notifications?
  end

  test "update as JSON" do
    patch notifications_settings_path, params: { new_subscriber_notifications: false }, as: :json

    assert_response :no_content
    assert_not @settings.reload.new_subscriber_notifications?
  end

  test "update changes only one's own settings" do
    patch notifications_settings_path, params: { user_settings: { new_subscriber_notifications: "0" } }

    assert users(:leo).settings.reload.new_subscriber_notifications?
  end

  test "the profile links to the page for an admin and not for a member" do
    get user_path(users(:mia))
    assert_select ".row a[href=?]", notifications_settings_path, text: /Notification settings/

    sign_in_as :nonstaff
    get user_path(users(:nonstaff))
    assert_select "a[href=?]", notifications_settings_path, count: 0
  end
end
