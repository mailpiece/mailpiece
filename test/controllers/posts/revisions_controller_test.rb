require "test_helper"

class Posts::RevisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :mia
  end

  test "show puts what the post said before beside what it says now" do
    get post_revision_path(posts(:draft), post_revisions(:draft_before))

    assert_response :success
    assert_select "h1", text: post_revisions(:draft_before).title
    assert_select "h1", text: posts(:draft).title
  end

  test "show the latest revision" do
    get post_revision_path(posts(:draft), "latest")

    assert_response :success
    assert_select "h1", text: post_revisions(:draft_before).title
  end

  test "index as JSON lists the post's revisions, with who wrote each and when" do
    get post_revisions_path(posts(:draft), format: :json)

    assert_response :success
    assert_equal [ post_revisions(:draft_before).id ], response.parsed_body.pluck("id")
    assert_equal users(:mia).id, response.parsed_body.first.dig("creator", "id")
    assert_equal post_revisions(:draft_before).created_at.utc.as_json, response.parsed_body.first["created_at"]
  end

  test "index as JSON of a post never edited is empty" do
    get post_revisions_path(posts(:sent), format: :json)

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show as JSON" do
    get post_revision_path(posts(:draft), post_revisions(:draft_before), format: :json)

    assert_response :success
    assert_equal post_revisions(:draft_before).id, response.parsed_body["id"]
    assert_equal "Keeping a contractor file", response.parsed_body["title"]
    assert_equal "The file used to start with two things.", response.parsed_body["body"]
    assert_includes response.parsed_body["body_html"], "<p>The file used to start with two things.</p>"
  end

  test "show as JSON keeps a box as it was written" do
    posts(:draft).update! body: %(<aside data-audience="email"><p>Reply to this email.</p></aside>)
    patch post_path(posts(:draft)), params: { post: { body: "<p>No box.</p>" } }

    get post_revision_path(posts(:draft), "latest", format: :json)

    box = Nokogiri::HTML5.fragment(response.parsed_body["body_html"]).at_css("aside")
    assert_equal [ "email", "Reply to this email." ], [ box["data-audience"], box.text.strip ]
  end

  test "a post never edited has no history" do
    get post_revision_path(posts(:sent), "latest")
    assert_response :not_found
  end

  test "a revision of another post is not found" do
    get post_revision_path(posts(:sent), post_revisions(:draft_before))
    assert_response :not_found
  end

  test "a revision of another account is not found" do
    get post_revision_path(posts(:other_accounts), post_revisions(:other_accounts_before))
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get post_revision_path(posts(:draft), "latest")

    assert_response :forbidden

    get post_revisions_path(posts(:draft), format: :json)

    assert_response :forbidden
  end

  test "show draws a box as a box, under its audience's name" do
    posts(:draft).update! body: %(<aside data-audience="email"><p>Reply to this email.</p></aside>)

    get post_revision_path(posts(:draft), "latest")

    assert_response :success
    assert_select ".writing__version--current aside[data-audience=email] p", text: "Reply to this email."
    assert_includes css_select(".page.writing").first["style"], %(--audience-email-label: "Only in the email")
  end
end
