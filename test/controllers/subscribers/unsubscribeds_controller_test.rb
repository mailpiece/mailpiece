require "test_helper"

class Subscribers::UnsubscribedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show lists the addresses in that state" do
    get subscribers_unsubscribed_path

    assert_response :success
    assert_match subscribers(:unsubscribed).email, response.body
    assert_no_match subscribers(:active).email, response.body
  end

  test "show as JSON lists the same addresses" do
    get subscribers_unsubscribed_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:unsubscribed).id ], response.parsed_body.pluck("id")
  end
end
