require "test_helper"

class SnippetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :leo
  end

  test "index lists the account's snippets by name" do
    get snippets_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", posts_path, text: "Posts"
    assert_select "a[href=?]", new_snippet_path, text: "Add a snippet"
    assert_select "ul.rows li.row", count: 3
    assert_select "input[data-quick-find-target=input]"
    assert_select "li.row[data-quick-find-target=item]", count: 3
    assert_equal [ "Reply to me", "Sign-off", "Subscribe" ], css_select("li.row .row__title").map(&:text)
    assert_select "li.row a[href=?]", edit_snippet_path(snippets(:sign_off)), text: "Sign-off"
    assert_select "li.row .row__meta", count: 0
    assert_select "li.row .status", count: 0
    assert_select "a[href=?]", edit_snippet_path(snippets(:other_accounts)), count: 0
  end

  test "index lights Posts in the bar" do
    get snippets_path

    assert_select ".site-header__link[aria-current=page][href=?]", posts_path
  end

  test "index shows a snippet that lands past the end of a full page" do
    12.times { |index| accounts(:davids_account).snippets.create!(name: "Note #{index}") }

    get snippets_path
    etag = response.headers["ETag"]

    accounts(:davids_account).snippets.create!(name: "Zebra")

    get snippets_path, headers: { "If-None-Match" => etag }
    assert_response :success
    assert_select "a.pagination-link[href=?]", snippets_path(page: 2)
  end

  test "index with no snippets offers to add one" do
    Snippet.where(account: accounts(:davids_account)).delete_all

    get snippets_path

    assert_response :success
    assert_select "ul.rows", count: 0
    assert_select ".blank-slate a[href=?]", new_snippet_path, text: "Add one"
  end

  test "index as JSON lists the account's snippets by name" do
    get snippets_path, as: :json

    assert_response :success
    assert_equal [ snippets(:reply).id, snippets(:sign_off).id, snippets(:subscribe).id ], response.parsed_body.pluck("id")
  end

  test "show as JSON" do
    snippets(:sign_off).update!(content: "<p>Until <strong>next</strong> week.</p>")

    get snippet_path(snippets(:sign_off), format: :json)

    assert_response :success
    assert_equal snippets(:sign_off).id, response.parsed_body["id"]
    assert_equal "Sign-off", response.parsed_body["name"]
    assert_equal "Until next week.", response.parsed_body["content"]
    assert_includes response.parsed_body["content_html"], "<strong>next</strong>"
    assert_equal snippet_url(snippets(:sign_off), format: :json), response.parsed_body["url"]
  end

  test "new has the one form, under Snippets" do
    get new_snippet_path

    assert_response :success
    assert_select ".breadcrumbs a[href=?]", snippets_path, text: "Snippets"
    assert_select "form[action=?]", snippets_path, count: 1
    assert_select ".writing form.writing__form textarea.post-form__title[name='snippet[name]']"
    assert_select "input[name='snippet[placement]']", count: 0
    assert_select "lexxy-editor.lexxy-content[name='snippet[content]']"
    assert_select ".writing-bar button[name=_method][value=delete]", count: 0
  end

  test "create adds a snippet and goes back to the list" do
    assert_difference -> { accounts(:davids_account).snippets.count }, +1 do
      post snippets_path, params: { snippet: { name: " Thanks ", content: "<p>Thanks for <strong>reading</strong>.</p>" } }
    end

    assert_redirected_to snippets_path
    assert_equal "Snippet saved", flash[:notice]

    snippet = accounts(:davids_account).snippets.find_by!(name: "Thanks")
    assert_equal "Thanks for reading.", snippet.content.to_plain_text
  end

  test "create as JSON" do
    assert_difference -> { accounts(:davids_account).snippets.count }, +1 do
      post snippets_path, params: { name: "Through the API", content: "<p>Thanks.</p>" }, as: :json
    end

    assert_response :created
    assert_equal "Through the API", response.parsed_body["name"]
    assert_equal "Thanks.", response.parsed_body["content"]
    assert_equal snippet_url(Snippet.find_by!(name: "Through the API"), format: :json), response.location
  end

  test "create as JSON refuses a blank name with its errors" do
    assert_no_difference -> { Snippet.count } do
      post snippets_path, params: { name: " " }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], response.parsed_body["name"]
  end

  test "create refuses a blank name, and shows the form again" do
    assert_no_difference -> { Snippet.count } do
      post snippets_path, params: { snippet: { name: " ", content: "<p>Thanks.</p>" } }
    end

    assert_response :unprocessable_entity
    assert_select ".error-explanation"
    assert_select "form[action=?]", snippets_path
  end

  test "create takes nothing else of the snippet" do
    post snippets_path, params: { snippet: { name: "Thanks", account_id: accounts(:other_account).id } }

    assert_equal accounts(:davids_account), Snippet.find_by!(name: "Thanks").account
  end

  test "edit has the form and the button to delete it" do
    get edit_snippet_path(snippets(:reply))

    assert_response :success
    assert_select ".breadcrumbs strong", text: "Reply to me"
    assert_select "form.writing__form[action=?]", snippet_path(snippets(:reply)), count: 1
    assert_select "textarea.post-form__title[name='snippet[name]']", text: "Reply to me"
    assert_select "lexxy-editor.lexxy-content[name='snippet[content]']"
    assert_select ".writing-bar button[name=_method][value=delete][formaction=?][data-turbo-confirm=?]", snippet_path(snippets(:reply)),
      "Delete Reply to me? Posts it was pasted into keep their copy.", text: "Delete snippet"
  end

  test "update saves and goes back to the list" do
    patch snippet_path(snippets(:sign_off)), params: { snippet: { name: "Farewell", content: "<p>Bye.</p>" } }

    assert_redirected_to snippets_path
    assert_equal "Snippet saved", flash[:notice]

    snippet = snippets(:sign_off).reload
    assert_equal "Farewell", snippet.name
    assert_equal "Bye.", snippet.content.to_plain_text
  end

  test "update refuses a blank name, and keeps the snippet's own name over the page" do
    patch snippet_path(snippets(:sign_off)), params: { snippet: { name: " " } }

    assert_response :unprocessable_entity
    assert_select ".error-explanation"
    assert_select ".breadcrumbs strong", text: "Sign-off"
    assert_equal "Sign-off", snippets(:sign_off).reload.name
  end

  test "update as JSON" do
    patch snippet_path(snippets(:sign_off), format: :json), params: { name: "Farewell", content: "<p>Bye.</p>" }, as: :json

    assert_response :success
    assert_equal "Farewell", response.parsed_body["name"]
    assert_equal "Bye.", snippets(:sign_off).reload.content.to_plain_text
  end

  test "update as JSON refuses a blank name with its errors" do
    patch snippet_path(snippets(:sign_off), format: :json), params: { name: " " }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], response.parsed_body["name"]
    assert_equal "Sign-off", snippets(:sign_off).reload.name
  end

  test "destroy deletes the snippet and goes back to the list" do
    assert_difference -> { accounts(:davids_account).snippets.count }, -1 do
      delete snippet_path(snippets(:sign_off))
    end

    assert_redirected_to snippets_path
    assert_equal "Sign-off was deleted.", flash[:notice]
    assert_not Snippet.exists?(snippets(:sign_off).id)
  end

  test "destroy as JSON answers with no content" do
    delete snippet_path(snippets(:sign_off), format: :json)

    assert_response :no_content
    assert_not Snippet.exists?(snippets(:sign_off).id)
  end

  test "destroy of a snippet already deleted is not found" do
    snippets(:sign_off).destroy!

    delete snippet_path(snippets(:sign_off))

    assert_response :not_found
  end

  test "another account's snippet is not found" do
    get edit_snippet_path(snippets(:other_accounts))
    assert_response :not_found

    patch snippet_path(snippets(:other_accounts)), params: { snippet: { name: "Mine" } }
    assert_response :not_found
    assert_equal "Theirs", snippets(:other_accounts).reload.name

    assert_no_difference -> { Snippet.count } do
      delete snippet_path(snippets(:other_accounts))
    end
    assert_response :not_found
  end

  test "members are refused" do
    sign_in_as :nonstaff

    get snippets_path
    assert_response :forbidden

    get new_snippet_path
    assert_response :forbidden

    assert_no_difference -> { Snippet.count } do
      post snippets_path, params: { snippet: { name: "Mine" } }
    end
    assert_response :forbidden

    get edit_snippet_path(snippets(:sign_off))
    assert_response :forbidden

    patch snippet_path(snippets(:sign_off)), params: { snippet: { name: "Mine" } }
    assert_response :forbidden
    assert_equal "Sign-off", snippets(:sign_off).reload.name

    assert_no_difference -> { Snippet.count } do
      delete snippet_path(snippets(:sign_off))
    end
    assert_response :forbidden
  end
end
