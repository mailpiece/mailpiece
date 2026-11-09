require "test_helper"

class Posts::DraftsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the drafts that are not scheduled under a crumb back to the posts" do
    get posts_draft_path

    assert_select ".breadcrumbs a[href=?]", posts_path, text: "Posts"
    assert_select ".breadcrumbs strong", text: "Drafts"
    assert_select "li##{dom_id(posts(:draft))}"
    assert_select "li##{dom_id(posts(:scheduled))}", count: 0
    assert_select "li##{dom_id(posts(:unlisted))}", count: 0
  end

  test "show names its state on the status menu's button and marks its line current" do
    get posts_draft_path

    assert_select ".filter-bar .status-filter button", text: "Drafts"
    assert_select ".status-filter a[aria-current=page][href=?]", posts_draft_path, text: /\ADrafts/
    assert_select ".status-filter a[aria-current]", count: 1
  end

  test "show as JSON lists the same posts" do
    get posts_draft_path, as: :json

    assert_response :success
    assert_equal [ posts(:draft).id ], response.parsed_body.pluck("id")
  end
end
