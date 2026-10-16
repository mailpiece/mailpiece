require "test_helper"

class Prompts::SnippetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "index offers the two audiences, then the account's snippets by name" do
    get prompts_snippets_path

    assert_response :success
    assert_equal [ "Only on the web onlyweb", "Only in the email onlyemail", "Reply to me", "Sign-off", "Subscribe" ], css_select("lexxy-prompt-item").map { it["search"] }
    assert_equal 5, response.body.scan(%(<template type="menu">)).size
    assert_equal 5, editor_templates.size
    assert_not_includes response.body, "<html"
  end

  test "index gives a snippet's content to paste, and nothing that points at the snippet" do
    snippets(:sign_off).update! content: "<p>Yours, <strong>Leo</strong></p><ul><li>One</li></ul>"

    get prompts_snippets_path

    assert_equal "<p>Yours, <strong>Leo</strong></p><ul><li>One</li></ul>", editor_templates[3]
    assert_equal 2, response.body.scan("Sign-off").size
    assert_select "lexxy-prompt-item[sgid]", count: 0
    assert_not_includes editor_templates.last(3).join, "sgid"
  end

  test "index gives a snippet with nothing written nothing to paste" do
    get prompts_snippets_path

    assert_equal [ "", "", "" ], editor_templates.last(3)
  end

  test "index gives what a snippet holds as the editor loads it" do
    snippets(:sign_off).update! content: %(<p>Reply to me.</p><aside data-audience="email"><p>Only you.</p></aside>) +
      %(<action-text-attachment content-type="image/png" url="https://example.com/ladder.png"></action-text-attachment>)

    get prompts_snippets_path

    pasted = Nokogiri::HTML5.fragment(editor_templates[3])
    assert_equal [ "email", "Only you." ], [ pasted.at_css("aside")["data-audience"], pasted.at_css("aside p").text ]
    assert_equal "https://example.com/ladder.png", pasted.at_css("action-text-attachment")["url"]
  end

  test "index lets nothing a snippet stores out of its template" do
    snippets(:sign_off).update! content: %(<p onclick="x()">Yours, Leo</p></template><script>alert(1)</script><template>)

    get prompts_snippets_path

    assert_equal 10, response.body.scan("<template").size
    assert_equal 10, response.body.scan("</template>").size
    assert_not_includes response.body, "<script"
    assert_not_includes response.body, "onclick"
    assert_includes editor_templates[3], "<p>Yours, Leo</p>"
  end

  test "index shows each audience's command beside its label in the menu" do
    get prompts_snippets_path

    assert_includes response.body, "<code>/onlyweb</code> Only on the web"
    assert_includes response.body, "<code>/onlyemail</code> Only in the email"
  end

  test "index gives an audience an empty box to paste, with a line to write on" do
    get prompts_snippets_path

    assert_equal [ %(<aside data-audience="web"><p><br></p></aside>), %(<aside data-audience="email"><p><br></p></aside>) ], editor_templates.first(2)
  end

  test "index finds an audience by its Spanish command in a newsletter written in Spanish" do
    accounts(:davids_account).update! locale: "es"

    get prompts_snippets_path

    assert_equal [ "Solo en la web soloweb", "Solo en el email soloemail" ], css_select("lexxy-prompt-item").first(2).map { it["search"] }
    assert_includes response.body, "<code>/soloweb</code> Solo en la web"
  end

  test "index leaves out another account's snippets" do
    get prompts_snippets_path

    assert_not_includes response.body, "Theirs"
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get prompts_snippets_path

    assert_response :forbidden
  end

  private
    def editor_templates
      response.body.scan(%r{<template type="editor">(.*?)</template>}m).flatten
    end
end
