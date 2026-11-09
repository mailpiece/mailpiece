require "test_helper"

class Subscribers::BouncedsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the addresses that bounced, the last to bounce first" do
    earlier = accounts(:davids_account).subscribers.create!(email: "earlier@example.com", bounced_at: 1.month.ago)

    get subscribers_bounced_path

    assert_select ".breadcrumbs strong", text: "Bounced"
    assert_equal [ dom_id(subscribers(:bounced)), dom_id(earlier) ], css_select("li.row[id^=subscriber_]").map { it["id"] }
    assert_select "li##{dom_id(subscribers(:bounced))} .row__meta", text: /\ASubscribed/
    assert_select "li##{dom_id(subscribers(:bounced))} .row__end time[datetime=?][data-reader-time-target=timeordate] + .status--error", subscribers(:bounced).bounced_at.to_i.to_s, text: "Bounced"
  end

  test "show names its state on the status menu's button and marks its line current" do
    get subscribers_bounced_path

    assert_select ".filter-bar .status-filter button", text: "Bounced"
    assert_select ".status-filter a[aria-current=page][href=?]", subscribers_bounced_path, text: /\ABounced/
    assert_select ".status-filter a[aria-current]", count: 1
  end

  test "show as JSON lists the same addresses" do
    get subscribers_bounced_path, as: :json

    assert_response :success
    assert_equal [ subscribers(:bounced).id ], response.parsed_body.pluck("id")
  end

  test "show keeps its cache when an address it does not list changes" do
    get subscribers_bounced_path
    etag = response.headers["ETag"]

    subscribers(:active).touch

    get subscribers_bounced_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "show invalidates its cache when an address it lists changes" do
    get subscribers_bounced_path
    etag = response.headers["ETag"]

    subscribers(:bounced).update!(bounced_at: 1.day.ago)

    get subscribers_bounced_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end
end
