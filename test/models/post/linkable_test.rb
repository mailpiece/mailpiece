require "test_helper"

class Post::LinkableTest < ActiveSupport::TestCase
  test "record_links writes a row for each address the email links to, with the text of its first link" do
    posts(:draft).update! body: <<~HTML
      <p><a href="https://example.com/rules">Read  the rules</a> and <a href="http://example.org/form">the form</a>.</p>
      <p>Again, <a href="https://example.com/rules">here</a>.</p>
    HTML

    assert_difference -> { posts(:draft).links.count }, 2 do
      posts(:draft).record_links
    end

    rules, form = posts(:draft).links.to_a

    assert_equal [ "https://example.com/rules", "https://example.com/rules", "Read the rules" ], [ rules.original_url, rules.url, rules.text ]
    assert_equal [ "http://example.org/form", "the form" ], [ form.original_url, form.text ]
    assert_equal accounts(:davids_account), rules.account
  end

  test "record_links takes web addresses only" do
    posts(:draft).update! body: %(<p><a href="mailto:leo@example.com">Write</a>, <a href="tel:+5491155550000">call</a> or <a href="/archive">read</a>.</p>)

    assert_no_difference -> { Post::Link.count } do
      posts(:draft).record_links
    end
  end

  test "record_links takes what the email reads and nothing of what is only on the web" do
    posts(:draft).update! body: %(<aside data-audience="email"><p><a href="https://example.com/reply">Reply</a></p></aside><aside data-audience="web"><p><a href="https://example.com/archive">Archive</a></p></aside>)
    posts(:draft).record_links

    assert_equal [ "https://example.com/reply" ], posts(:draft).links.map(&:original_url)
  end

  test "record_links called again writes nothing and keeps a corrected destination" do
    posts(:sent).update! body: %(<p><a href="https://forms.example.com/training">Sign up here</a> or <a href="https://example.com/new">read</a>.</p>)
    post_links(:training).update! url: "https://forms.example.com/training-2"

    assert_difference -> { posts(:sent).links.count }, 1 do
      2.times { posts(:sent).record_links }
    end

    assert_equal "https://forms.example.com/training-2", post_links(:training).reload.url
    assert_equal "7k2m9qxa", post_links(:training).code
  end

  test "record_links of a post with no text writes nothing" do
    post = Current.account.posts.create!(title: "Empty")

    assert_no_difference -> { Post::Link.count } do
      post.record_links
    end
  end

  test "deliver records the links of the issue it sends" do
    posts(:draft).update! body: %(<p><a href="https://example.com/rules">Read the rules</a></p>)

    assert posts(:draft).deliver
    assert_equal [ "https://example.com/rules" ], posts(:draft).links.map(&:original_url)
  end

  test "a post never mailed has no links: one only published, and one with nobody to send to" do
    posts(:draft).update! body: %(<p><a href="https://example.com/rules">Read the rules</a></p>)
    subscribers(:active).unsubscribe

    assert_no_difference -> { Post::Link.count } do
      posts(:draft).publish
      assert_not posts(:draft).deliver
    end
  end
end
