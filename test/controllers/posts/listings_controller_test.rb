require "test_helper"

class Posts::ListingsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    sign_in_as :mia
  end

  test "create" do
    assert_changes -> { posts(:unlisted).reload.listed? }, from: false, to: true do
      post post_listing_path(posts(:unlisted)), as: :turbo_stream
    end

    assert_turbo_stream action: :replace, target: dom_id(posts(:unlisted), :listing) do
      assert_select "button[aria-checked=true][disabled]", text: "Listed"
      assert_select "button[aria-checked=false]:not([disabled])", text: "By link only"
    end
    assert_select "turbo-stream[method=morph][target=?]", dom_id(posts(:unlisted), :listing)
    assert_turbo_stream action: :update, target: dom_id(posts(:unlisted), :detail)
    assert_turbo_stream action: :replace, target: "flash" do
      assert_select "template", text: /Saved/
    end
  end

  test "destroy" do
    assert_changes -> { posts(:sent).reload.unlisted? }, from: false, to: true do
      delete post_listing_path(posts(:sent)), as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: dom_id(posts(:sent), :detail) do
      assert_select "template", text: /Unlisted/
    end
  end

  test "create as JSON" do
    post post_listing_path(posts(:unlisted)), as: :json

    assert_response :no_content
    assert posts(:unlisted).reload.listed?
  end

  test "destroy as JSON" do
    delete post_listing_path(posts(:sent)), as: :json

    assert_response :no_content
    assert posts(:sent).reload.unlisted?
  end

  test "either one twice changes nothing more" do
    2.times { delete post_listing_path(posts(:unlisted)), as: :turbo_stream }
    assert_response :success
    assert posts(:unlisted).reload.unlisted?

    2.times { post post_listing_path(posts(:sent)), as: :turbo_stream }
    assert posts(:sent).reload.listed?
  end

  test "a draft and an issue with no page are refused and left as they are" do
    assert_no_changes -> { posts(:draft).reload.visibility } do
      delete post_listing_path(posts(:draft)), as: :turbo_stream
    end
    assert_response :forbidden

    assert_no_changes -> { posts(:email_only).reload.visibility } do
      post post_listing_path(posts(:email_only)), as: :turbo_stream
    end
    assert_response :forbidden
    assert_empty response.body
  end

  test "a draft and an issue with no page are refused as JSON with why" do
    delete post_listing_path(posts(:draft)), as: :json
    assert_response :forbidden
    assert_equal "Only a post published on the web is listed or unlisted", response.parsed_body["error"]

    post post_listing_path(posts(:email_only)), as: :json
    assert_response :forbidden
    assert_equal "Only a post published on the web is listed or unlisted", response.parsed_body["error"]
    assert posts(:email_only).reload.email_only?
  end

  test "neither changes the post's text or date" do
    assert_no_changes -> { posts(:sent).reload.attributes.slice("title", "published_at", "sent_at") } do
      delete post_listing_path(posts(:sent), format: :turbo_stream), params: { post: { title: "Another title" } }
    end
  end
end
