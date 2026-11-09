require "test_helper"

class Notifications::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
    @settings = users(:mia).settings
  end

  test "show" do
    get notifications_settings_path

    assert_response :success
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

    patch notifications_settings_path, params: { user_settings: { new_subscriber_notifications: "1" } }
    assert @settings.reload.new_subscriber_notifications?
  end

  test "update as JSON" do
    patch notifications_settings_path, params: { new_subscriber_notifications: false }, as: :json

    assert_response :no_content
    assert_not @settings.reload.new_subscriber_notifications?
  end

  test "update switches the forwarding of replies off and on, and the other switch stays" do
    patch notifications_settings_path, params: { user_settings: { reply_forwarding: "0", new_subscriber_notifications: "1" } }

    assert_redirected_to notifications_settings_path
    assert_not @settings.reload.reply_forwarding?
    assert @settings.new_subscriber_notifications?

    patch notifications_settings_path, params: { reply_forwarding: true }, as: :json
    assert @settings.reload.reply_forwarding?

    get notifications_settings_path, as: :json
    assert_equal true, response.parsed_body["reply_forwarding"]
  end

  test "update changes only one's own settings" do
    patch notifications_settings_path, params: { user_settings: { new_subscriber_notifications: "0" } }

    assert users(:leo).settings.reload.new_subscriber_notifications?
  end

  test "the profile links to the page for an admin and not for a member" do
    get user_path(users(:mia))
    assert_select "a[href=?]", notifications_settings_path

    sign_in_as :nonstaff
    get user_path(users(:nonstaff))
    assert_select "a[href=?]", notifications_settings_path, count: 0
  end
end
