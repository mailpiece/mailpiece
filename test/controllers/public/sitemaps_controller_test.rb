require "test_helper"

class Public::SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "show lists the index and what is published and listed" do
    get public_sitemap_path

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match "public", response.headers["Cache-Control"]
    assert_includes response.body, "<loc>#{root_url}</loc>"
    assert_includes response.body, "<loc>#{public_post_url(posts(:sent).public_param)}</loc>"

    %i[ draft scheduled unlisted email_only other_accounts ].each do |post|
      assert_not_includes response.body, posts(post).code
    end
  end

  test "a cancelled account is not found" do
    accounts(:davids_account).create_cancellation!(initiated_by: users(:leo))

    get public_sitemap_path

    assert_response :not_found
  end
end
