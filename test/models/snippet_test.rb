require "test_helper"

class SnippetTest < ActiveSupport::TestCase
  setup do
    @snippets = accounts(:davids_account).snippets
  end

  test "a snippet belongs to the current account" do
    assert_equal accounts(:davids_account), Snippet.create!(name: "Footer").account
  end

  test "name is squished, and required" do
    assert_equal "Sign off", @snippets.create!(name: "  Sign   off ").name

    snippet = @snippets.new(name: " ")
    assert_not snippet.valid?
    assert snippet.errors.of_kind?(:name, :blank)
  end

  test "content is rich text" do
    snippets(:sign_off).update!(content: "<p>Until <strong>next week</strong>.</p>")

    assert_equal "Until next week.", snippets(:sign_off).reload.content.to_plain_text
  end

  test "alphabetically sorts by name" do
    assert_equal snippets(:reply, :sign_off, :subscribe), @snippets.alphabetically.to_a
  end

  test "destroy takes its content with it, and leaves a post it was pasted into as it was" do
    snippets(:sign_off).update! content: "<p>Yours, Leo</p>"
    posts(:sent).update! body: "<p>Hello.</p><p>Yours, Leo</p>"

    assert_difference -> { ActionText::RichText.where(record_type: "Snippet").count }, -1 do
      snippets(:sign_off).destroy!
    end

    assert_equal "<p>Hello.</p><p>Yours, Leo</p>", posts(:sent).reload.body.body.to_html
  end
end
