require "test_helper"

class Subscribers::DeactivatedsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the addresses in that state under a crumb back to the subscribers" do
    get subscribers_deactivated_path

    assert_select ".breadcrumbs a[href=?]", subscribers_path, text: "Subscribers"
    assert_select ".breadcrumbs strong", text: "Stopped"
    assert_select "li##{dom_id(subscribers(:stopped))} .row__meta", text: /\AStopped/
    assert_select "li##{dom_id(subscribers(:active))}", count: 0
  end

  test "show names its state on the status menu's button and marks its line current" do
    get subscribers_deactivated_path

    assert_select ".filter-bar .status-filter button", text: "Stopped"
    assert_select ".status-filter a[aria-current=page][href=?]", subscribers_deactivated_path, text: /\AStopped/
    assert_select ".status-filter a[aria-current]", count: 1
  end

  test "show as JSON lists the same addresses" do
    get subscribers_deactivated_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:stopped).id ], response.parsed_body.pluck("id")
  end
end
