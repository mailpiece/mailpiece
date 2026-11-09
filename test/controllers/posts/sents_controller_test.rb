require "test_helper"

class Posts::SentsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what was mailed and says when each went out" do
    get posts_sent_path

    assert_select ".breadcrumbs strong", text: "Sent"
    assert_select "li##{dom_id(posts(:sent))} .row__meta", text: "2 subscribers"
    assert_select "li##{dom_id(posts(:sent))} .row__end time[datetime=?][data-reader-time-target=timeordate] + .status--muted", posts(:sent).sent_at.to_i.to_s, text: "Sent"
    assert_select "li##{dom_id(posts(:draft))}", count: 0
  end

  test "show names its state on the status menu's button and marks its line current" do
    get posts_sent_path

    assert_select ".filter-bar .status-filter button", text: "Sent"
    assert_select ".status-filter a[aria-current=page][href=?]", posts_sent_path, text: /\ASent/
    assert_select ".status-filter a[aria-current]", count: 1
  end

  test "show as JSON lists the same posts" do
    get posts_sent_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).posts.sent.recently_published_first.ids, response.parsed_body.pluck("id")
  end
end
