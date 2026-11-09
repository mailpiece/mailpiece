require "test_helper"

class Posts::SentsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what was mailed" do
    get posts_sent_path

    assert_select "li##{dom_id(posts(:sent))}"
    assert_select "li##{dom_id(posts(:draft))}", count: 0
  end

  test "show as JSON lists the same posts" do
    get posts_sent_path, as: :json

    assert_response :success
    assert_equal accounts(:davids_account).posts.sent.recently_published_first.ids, response.parsed_body.pluck("id")
  end
end
