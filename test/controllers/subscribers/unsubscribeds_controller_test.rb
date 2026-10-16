require "test_helper"

class Subscribers::UnsubscribedsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the addresses in that state under a crumb back to the subscribers" do
    get subscribers_unsubscribed_path

    assert_select ".breadcrumbs a[href=?]", subscribers_path, text: "Subscribers"
    assert_select ".breadcrumbs strong", text: "Unsubscribed"
    assert_select "li##{dom_id(subscribers(:unsubscribed))} .row__meta", text: /\AUnsubscribed/
    assert_select "li##{dom_id(subscribers(:active))}", count: 0
  end

  test "show as JSON lists the same addresses" do
    get subscribers_unsubscribed_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:unsubscribed).id ], response.parsed_body.pluck("id")
  end
end
