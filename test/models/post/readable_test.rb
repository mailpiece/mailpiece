require "test_helper"

class Post::ReadableTest < ActiveSupport::TestCase
  test "a post with no text has none to read" do
    post = Current.account.posts.create!(title: "Empty")

    assert_nil post.body_on_the_web
    assert_nil post.body_in_email
  end

  test "what a box holds is ordinary text for its audience and nothing for the other, and what is around it is for everyone" do
    posts(:sent).update! body: "<p>Hello.</p>#{box(:web, "<p>Read the archive.</p>")}#{box(:email, "<p>Reply to this email.</p>")}<p>Bye.</p>"

    assert_equal "<p>Hello.</p><p>Read the archive.</p><p>Bye.</p>", posts(:sent).body_on_the_web.to_html
    assert_equal "<p>Hello.</p><p>Reply to this email.</p><p>Bye.</p>", posts(:sent).body_in_email.to_html
  end

  test "a box holds whatever a post does: paragraphs, a list, a link, a picture" do
    posts(:sent).update! body: box(:email, %(<p>Reply to <a href="https://example.com/me">me</a>.</p><ul><li>One</li></ul>#{picture}))

    email = posts(:sent).body_in_email
    assert_equal [ "https://example.com/me" ], email.fragment.find_all("p a").map { it["href"] }
    assert_equal [ "One" ], email.fragment.find_all("li").map(&:text)
    assert_equal [ "https://example.com/ladder.png" ], email.attachables.map(&:url)

    assert_equal "", posts(:sent).body_on_the_web.to_html
    assert_empty posts(:sent).body_on_the_web.attachables
  end

  test "no box is left in what a reader gets, and an empty one leaves nothing" do
    posts(:sent).update! body: "<p>Hello.</p>#{box(:web, "")}#{box(:email, "")}#{box(:web, "<p>Read the archive.</p>")}"

    assert_equal "<p>Hello.</p><p>Read the archive.</p>", posts(:sent).body_on_the_web.to_html
    assert_equal "<p>Hello.</p>", posts(:sent).body_in_email.to_html
  end

  test "a box of no audience we know is opened for everyone" do
    posts(:sent).update! body: %(<aside data-audience="print"><p>Kept.</p></aside><aside><p>Not a box.</p></aside>)

    assert_equal "<p>Kept.</p><aside><p>Not a box.</p></aside>", posts(:sent).body_on_the_web.to_html
    assert_equal "<p>Kept.</p><aside><p>Not a box.</p></aside>", posts(:sent).body_in_email.to_html
  end

  test "the post itself keeps its boxes" do
    posts(:sent).update! body: box(:web, "<p>Read the archive.</p>")

    posts(:sent).body_on_the_web
    posts(:sent).body_in_email

    assert_equal [ "web" ], posts(:sent).reload.body.body.fragment.find_all("aside").map { it["data-audience"] }
  end

  test "excerpt and lead_image read the post as the web shows it" do
    posts(:sent).update! body: %(<p>Hello.</p>#{box(:email, %(<p>Reply to this email.</p><action-text-attachment content-type="image/png" url="https://example.com/reply.png"></action-text-attachment>))}#{box(:web, "<p>Subscribe on the site.</p>")}#{picture})

    assert_equal "Hello. Subscribe on the site.", posts(:sent).excerpt
    assert_equal "https://example.com/ladder.png", posts(:sent).lead_image.url
  end

  private
    def box(medium, html)
      %(<aside data-audience="#{medium}">#{html}</aside>)
    end

    def picture
      %(<action-text-attachment content-type="image/png" url="https://example.com/ladder.png"></action-text-attachment>)
    end
end
