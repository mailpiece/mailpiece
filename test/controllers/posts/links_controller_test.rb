require "test_helper"

class Posts::LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "index as JSON lists the links the issue went out with" do
    get post_links_path(posts(:sent), format: :json)

    assert_response :success
    assert_equal posts(:sent).links.ids, response.parsed_body.pluck("id")

    link = response.parsed_body.find { |link| link["id"] == post_links(:training).id }
    assert_equal "7k2m9qxa", link["code"]
    assert_equal "Sign up here", link["text"]
    assert_equal "https://forms.example.com/training", link["url"]
    assert_equal "https://forms.example.com/training", link["original_url"]
    assert_equal true, link["stale"]
  end

  test "edit is the form for that link in its frame" do
    get edit_post_link_path(posts(:sent), post_links(:training))

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(post_links(:training))}" do
      assert_select "form[action=?]", post_link_path(posts(:sent), post_links(:training)) do
        assert_select "input[name='post_link[url]'][value=?]", "https://forms.example.com/training"
      end
    end
  end

  test "update corrects where a link leads" do
    patch post_link_path(posts(:sent), post_links(:training)), params: { post_link: { url: "https://forms.example.com/training-2" } }

    assert_redirected_to post_results_path(posts(:sent))
    assert_equal "https://forms.example.com/training-2", post_links(:training).reload.url
  end

  test "update as JSON answers with the link" do
    patch post_link_path(posts(:sent), post_links(:training)), params: { url: "https://forms.example.com/training-2" }, as: :json

    assert_response :success
    assert_equal post_links(:training).id, response.parsed_body["id"]
    assert_equal "https://forms.example.com/training-2", response.parsed_body["url"]
    assert_equal "https://forms.example.com/training", response.parsed_body["original_url"]
    assert_equal "https://forms.example.com/training-2", post_links(:training).reload.url
  end

  test "update as JSON refuses what is not a web address, and says why" do
    assert_no_changes -> { post_links(:training).reload.url } do
      patch post_link_path(posts(:sent), post_links(:training)), params: { url: "javascript:alert(1)" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "must be a full address starting with http:// or https://" ], response.parsed_body["url"]
  end

  test "update changes the destination and nothing else" do
    assert_no_changes -> { post_links(:training).reload.attributes.except("url", "updated_at") } do
      patch post_link_path(posts(:sent), post_links(:training)),
        params: { post_link: { url: "https://forms.example.com/training-2", original_url: "https://example.com/ours", text: "Ours", code: "ours" } }
    end

    assert_equal "https://forms.example.com/training-2", post_links(:training).reload.url
  end

  test "update refuses what is not a web address, and says why in the link's frame" do
    assert_no_changes -> { post_links(:training).reload.url } do
      patch post_link_path(posts(:sent), post_links(:training)), params: { post_link: { url: "javascript:alert(1)" } }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(post_links(:training))}" do
      assert_select ".error-explanation__message", text: "Destination must be a full address starting with http:// or https://"
      assert_select "input[name='post_link[url]'][value=?]", "javascript:alert(1)"
    end
  end

  test "a link of another post is not found" do
    get edit_post_link_path(posts(:draft), post_links(:training))
    assert_response :not_found

    patch post_link_path(posts(:draft), post_links(:training)), params: { post_link: { url: "https://example.com/ours" } }

    assert_response :not_found
    assert_equal "https://forms.example.com/training", post_links(:training).reload.url
  end

  test "a post of another account is not found" do
    get post_links_path(posts(:other_accounts), format: :json)
    assert_response :not_found

    patch post_link_path(posts(:other_accounts), post_links(:training)), params: { post_link: { url: "https://example.com/ours" } }
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get post_links_path(posts(:sent), format: :json)
    assert_response :forbidden

    get edit_post_link_path(posts(:sent), post_links(:training))
    assert_response :forbidden

    patch post_link_path(posts(:sent), post_links(:training)), params: { post_link: { url: "https://example.com/ours" } }
    assert_response :forbidden
    assert_equal "https://forms.example.com/training", post_links(:training).reload.url
  end
end
