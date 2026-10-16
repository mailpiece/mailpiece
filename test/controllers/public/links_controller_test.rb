require "test_helper"

class Public::LinksControllerTest < ActionDispatch::IntegrationTest
  test "show sends the reader where the link leads" do
    get public_link_path(post_links(:training).code)

    assert_response :found
    assert_redirected_to "https://forms.example.com/training"
  end

  test "show follows a destination corrected after the issue went out" do
    post_links(:training).update! url: "https://forms.example.com/training-2"

    get public_link_path(post_links(:training).code)

    assert_redirected_to "https://forms.example.com/training-2"
  end

  test "an unknown code is not found" do
    get public_link_path("zzzzzzzz")

    assert_response :not_found
  end

  test "another account's code is not found" do
    link = posts(:other_accounts).links.create!(original_url: "https://example.com/theirs", url: "https://example.com/theirs")

    get public_link_path(link.code)

    assert_response :not_found
  end

  test "a cancelled account is not found" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    get public_link_path(post_links(:training).code)

    assert_response :not_found
  end
end
