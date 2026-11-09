require "test_helper"

class Posts::ResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show lists the links the issue went out with, each with where it leads now" do
    get post_results_path(posts(:sent))

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(post_links(:training))}" do
      assert_select "strong", text: "Sign up here"
      assert_select "span", text: "https://forms.example.com/training"
      assert_select "a[href=?]", edit_post_link_path(posts(:sent), post_links(:training)), text: "Edit"
    end
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(post_links(:handbook))}" do
      assert_select "strong", text: "the handbook"
      assert_select "span", text: "https://example.com/handbook/ladders"
    end
  end

  test "show of a post never mailed says no links were mailed" do
    get post_results_path(posts(:draft))

    assert_response :success
    assert_select "turbo-frame[id^=post_link_]", count: 0
    assert_select ".blank-slate", text: "No links were mailed with this post."
  end

  test "a post of another account is not found" do
    get post_results_path(posts(:other_accounts))
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get post_results_path(posts(:sent))
    assert_response :forbidden
  end
end
