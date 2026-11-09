require "test_helper"

class Subscribers::ActivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show lists the addresses in that state" do
    get subscribers_active_path

    assert_response :success
    assert_match subscribers(:active).email, response.body
    assert_no_match subscribers(:unsubscribed).email, response.body
  end

  test "show as JSON lists the same addresses" do
    get subscribers_active_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).subscribers.active.reverse_chronologically.ids, response.parsed_body.pluck("id")
  end
end
