require "test_helper"

class Post::LinkTest < ActiveSupport::TestCase
  test "a link gets a code of eight lowercase letters and digits" do
    link = posts(:sent).links.create!(original_url: "https://example.com/new", url: "https://example.com/new")

    assert_match(/\A[a-z0-9]{8}\z/, link.code)
    assert_equal accounts(:davids_account), link.account
  end

  test "a code is taken once in an account, and another account may hold the same" do
    taken = post_links(:training).code

    here = posts(:draft).links.create!(code: taken, original_url: "https://example.com/a", url: "https://example.com/a")
    there = posts(:other_accounts).links.create!(code: taken, original_url: "https://example.com/a", url: "https://example.com/a")

    assert_not_equal taken, here.code
    assert_equal taken, there.code
  end

  test "the text is kept on one line and cut to what the column holds" do
    link = posts(:sent).links.create!(original_url: "https://example.com/new", url: "https://example.com/new", text: "  Read\n the  rules #{"x" * 300}")

    assert link.text.start_with?("Read the rules x")
    assert_equal 255, link.text.length
  end

  test "a destination is a web address" do
    [ "https://example.com/corrected", "http://example.com" ].each do |address|
      assert post_links(:training).update(url: address), address
    end

    [ "", "example.com", "mailto:leo@example.com", "javascript:alert(1)", "/posts", "https://example.com/a b", "https://example.com\nx" ].each do |address|
      assert_not post_links(:training).update(url: address), address
      assert post_links(:training).errors[:url].any?
    end
  end

  test "a link is stale once the email no longer has it and nobody corrected it" do
    posts(:sent).update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a></p>)

    assert_not post_links(:training).stale?
    assert post_links(:handbook).stale?

    post_links(:handbook).update! url: "https://example.com/handbook/scaffolds"

    assert_not post_links(:handbook).stale?
  end

  test "a link only the web reads is stale" do
    posts(:sent).update! body: %(<aside data-audience="web"><p><a href="https://forms.example.com/training">Sign up here</a></p></aside>)

    assert post_links(:training).stale?
  end
end
