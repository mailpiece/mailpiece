require "test_helper"

class Posts::PublishedsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists what is published with a page, mailed or not, under a crumb back to the posts" do
    get posts_published_path

    assert_select ".breadcrumbs a[href=?]", posts_path, text: "Posts"
    assert_select ".breadcrumbs strong", text: "Published"
    assert_select "li##{dom_id(posts(:unlisted))}"
    assert_select "li##{dom_id(posts(:sent))}"
    assert_select "li##{dom_id(posts(:draft))}", count: 0
    assert_select "li##{dom_id(posts(:email_only))}", count: 0
  end

  test "show as JSON lists the same posts" do
    get posts_published_path, as: :json

    assert_response :success
    assert_equal [ posts(:unlisted).id, posts(:sent).id ], response.parsed_body.pluck("id")
  end
end
