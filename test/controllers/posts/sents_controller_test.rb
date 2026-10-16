require "test_helper"

class Posts::SentsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what was mailed and says when each went out" do
    get posts_sent_path

    assert_select ".breadcrumbs strong", text: "Sent"
    assert_select "li##{dom_id(posts(:sent))} .row__meta", text: /\ASent to 2 subscribers on/ do
      assert_select "time[datetime=?][data-reader-time-target=shortdate]", posts(:sent).sent_at.to_i.to_s
    end
    assert_select "li##{dom_id(posts(:draft))}", count: 0
  end

  test "show as JSON lists the same posts" do
    get posts_sent_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).posts.sent.recently_published_first.ids, response.parsed_body.pluck("id")
  end
end
