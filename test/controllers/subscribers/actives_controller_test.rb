require "test_helper"

class Subscribers::ActivesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the addresses in that state under a crumb back to the subscribers" do
    get subscribers_active_path

    assert_select ".breadcrumbs a[href=?]", subscribers_path, text: "Subscribers"
    assert_select ".breadcrumbs strong", text: "Confirmed"
    assert_select "li##{dom_id(subscribers(:active))} .row__meta", text: /\ASubscribed/
    assert_select "li##{dom_id(subscribers(:unsubscribed))}", count: 0
    assert_select "li .separator--horizontal, li .status", count: 0
  end

  test "show as JSON lists the same addresses" do
    get subscribers_active_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).subscribers.active.reverse_chronologically.ids, response.parsed_body.pluck("id")
  end
end
