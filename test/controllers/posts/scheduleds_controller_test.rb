require "test_helper"

class Posts::ScheduledsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what is scheduled, from the latest to the soonest as JSON" do
    posts(:draft).schedule(at: 2.days.from_now)

    get posts_scheduled_path
    assert_select "li##{dom_id(posts(:draft))}"
    assert_select "li##{dom_id(posts(:scheduled))}"
    assert_select "li##{dom_id(posts(:sent))}", count: 0

    get posts_scheduled_path, as: :json
    assert_equal [ posts(:draft).id, posts(:scheduled).id ], response.parsed_body.pluck("id")
  end
end
