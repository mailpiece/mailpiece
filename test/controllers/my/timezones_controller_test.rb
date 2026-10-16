require "test_helper"

class My::TimezonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :nonstaff
    @user = users(:nonstaff)
  end

  test "update" do
    time_zone = ActiveSupport::TimeZone["America/New_York"]
    assert_not_equal time_zone, @user.timezone

    patch my_timezone_path, params: { timezone_name: "America/New_York" }

    assert_response :no_content
    assert_equal time_zone, @user.reload.timezone
  end

  test "update as JSON" do
    patch my_timezone_path, params: { timezone_name: "America/Chicago" }, as: :json

    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["America/Chicago"], @user.reload.timezone
  end

  test "update changes only one's own time zone" do
    patch my_timezone_path, params: { timezone_name: "America/New_York" }

    assert_nil users(:anlab).settings.reload.timezone_name
  end

  test "a zone nobody knows reads as UTC" do
    patch my_timezone_path, params: { timezone_name: "Mars/Olympus" }

    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["UTC"], @user.reload.timezone
  end
end
