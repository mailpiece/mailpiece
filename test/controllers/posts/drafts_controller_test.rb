require "test_helper"

class Posts::DraftsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "show lists the drafts that are not scheduled" do
    get posts_draft_path

    assert_select "li##{dom_id(posts(:draft))}"
    assert_select "li##{dom_id(posts(:scheduled))}", count: 0
    assert_select "li##{dom_id(posts(:unlisted))}", count: 0
  end

  test "show as JSON lists the same posts" do
    get posts_draft_path, as: :json

    assert_response :success
    assert_equal [ posts(:draft).id ], response.parsed_body.pluck("id")
  end
end
