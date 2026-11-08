require "test_helper"

class Posts::ScheduledsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what is scheduled from the latest to the soonest, on the screen and as JSON" do
    posts(:draft).schedule(at: 2.days.from_now)

    get posts_scheduled_path
    assert_select ".breadcrumbs strong", text: "Scheduled"
    assert_equal [ posts(:draft), posts(:scheduled) ].map { |post| dom_id(post) }, css_select("ul.rows li.row").pluck("id")

    get posts_scheduled_path, as: :json
    assert_equal [ posts(:draft).id, posts(:scheduled).id ], response.parsed_body.pluck("id")
  end

  test "show names its state on the status menu's button and marks its line current" do
    get posts_scheduled_path

    assert_select ".filter-bar .status-filter button", text: "Scheduled"
    assert_select ".status-filter a[aria-current=page][href=?]", posts_scheduled_path, text: /\AScheduled/
    assert_select ".status-filter a[aria-current]", count: 1
  end
end
