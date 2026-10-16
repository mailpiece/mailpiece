require "test_helper"

class Post::EditableTest < ActiveSupport::TestCase
  test "edit keeps what the post said before as a revision" do
    assert_difference -> { posts(:draft).revisions.count }, +1 do
      posts(:draft).edit title: "The file", body: "<p>New text.</p>"
    end

    assert_equal "The file", posts(:draft).reload.title
    assert_equal "New text.", posts(:draft).body.to_plain_text

    revision = posts(:draft).revisions.last
    assert_equal "How to keep a contractor file", revision.title
    assert_equal "The file starts with three things.", revision.body.to_plain_text
    assert_equal users(:leo), revision.creator
  end

  test "edits within ten minutes share one revision" do
    assert_difference -> { posts(:draft).revisions.count }, +1 do
      posts(:draft).edit body: "<p>First change</p>"
    end

    travel 1.minute

    assert_no_difference -> { posts(:draft).revisions.count } do
      posts(:draft).edit body: "<p>Second change</p>"
    end

    assert_equal "Second change", posts(:draft).reload.body.to_plain_text
    assert_equal "The file starts with three things.", posts(:draft).revisions.last.body.to_plain_text

    travel 1.hour

    assert_difference -> { posts(:draft).revisions.count }, +1 do
      posts(:draft).edit body: "<p>Third change</p>"
    end
  end

  test "an edit that changes neither the title nor the body records nothing" do
    assert_no_difference -> { Post::Revision.count } do
      posts(:draft).edit({})
      posts(:draft).edit title: posts(:draft).title, visibility: "email_only"
    end

    assert posts(:draft).reload.email_only?
  end

  test "an edit that does not save records nothing" do
    assert_no_difference -> { Post::Revision.count } do
      assert_not posts(:draft).edit(title: "The file", visibility: "nowhere")
    end

    assert_equal "How to keep a contractor file", posts(:draft).reload.title
  end

  test "edit takes the title off a draft, and leaves a published post Untitled" do
    assert posts(:draft).edit(title: " ")
    assert_nil posts(:draft).reload.title

    assert posts(:sent).edit(title: "")
    assert_equal "Untitled", posts(:sent).reload.title
  end

  test "edit corrects a published post" do
    assert posts(:sent).edit(title: "Four deadlines in March")

    assert_equal "Four deadlines in March", posts(:sent).reload.title
  end

  test "edit_draft refuses a published post" do
    assert_not posts(:sent).edit_draft(title: "Four deadlines in March")

    assert_equal "Three deadlines in March", posts(:sent).reload.title
  end

  test "edit_from_editor of a draft writes a draft and refuses a published post" do
    assert posts(:draft).edit_from_editor({ title: "The file" }, of_draft: true)
    assert_equal "The file", posts(:draft).reload.title

    assert_not posts(:sent).edit_from_editor({ title: "Four deadlines in March" }, of_draft: true)
    assert_empty posts(:sent).errors
    assert_equal "Three deadlines in March", posts(:sent).reload.title
  end

  test "edit_from_editor of a published post corrects it" do
    assert posts(:sent).edit_from_editor({ title: "Four deadlines in March" }, of_draft: false)

    assert_equal "Four deadlines in March", posts(:sent).reload.title
  end
end
