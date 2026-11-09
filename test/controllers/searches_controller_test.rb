require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Post.find_each(&:reindex)
    sign_in_as :mia
  end

  test "show lists the posts whose title matches, whatever their state" do
    get search_path(q: "MARCH")

    assert_response :success
    assert_listed posts(:sent), posts(:unlisted)
  end

  test "show lists the posts whose text matches" do
    get search_path(q: "insurance")

    assert_listed posts(:scheduled)
  end

  test "show lists the posts that match part of a word" do
    get search_path(q: "Marc")

    assert_listed posts(:sent), posts(:unlisted)
  end

  test "show with a term under three letters lists no post" do
    get search_path(q: "Ma")

    assert_listed
  end

  test "show reads a word the index would take for an operator as a word" do
    get search_path(q: "NOT")

    assert_response :success
    assert_match edit_post_path(posts(:unlisted)), response.body

    get search_path(q: "cats AND")

    assert_response :success
    assert_listed
  end

  test "show reads a query with a stray quote or punctuation as its words" do
    get search_path(q: %(the "insurance?))

    assert_listed posts(:scheduled)
  end

  test "show lists the posts whose summary matches" do
    posts(:draft).update! summary: "A checklist for the auditor"

    get search_path(q: "checklist")

    assert_listed posts(:draft)
  end

  test "show finds a word whatever its accents" do
    posts(:draft).update! body: "<p>La inspección empieza por el seguro.</p>"

    get search_path(q: "inspeccion")
    assert_match edit_post_path(posts(:draft)), response.body

    posts(:draft).update! body: "<p>La inspeccion empieza por el seguro.</p>"

    get search_path(q: "inspección")
    assert_match edit_post_path(posts(:draft)), response.body
  end

  test "show finds what a box keeps for the web and not what one keeps for the email" do
    posts(:draft).update! body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this letter.</p></aside><aside data-audience="web"><p>Subscribe on the site.</p></aside>)

    get search_path(q: "subscribe on the site")
    assert_match edit_post_path(posts(:draft)), response.body

    get search_path(q: "letter")
    assert_listed
  end

  test "show stops finding a post by the text it no longer has" do
    posts(:scheduled).update! body: "<p>Rewritten.</p>"

    get search_path(q: "insurance")

    assert_listed
  end

  test "show never lists another account's post" do
    get search_path(q: "another account")

    assert_listed
    assert_no_match "A post from another account", response.body
    assert_no_match edit_post_path(posts(:other_accounts)), response.body
  end

  test "show lists the addresses that match, whatever their state, and never another account's" do
    get search_path(q: subscribers(:bounced).email.first(3).upcase)

    assert_match subscriber_path(subscribers(:bounced)), response.body
    assert_no_match subscriber_path(subscribers(:active)), response.body

    get search_path(q: "ada@")

    assert_match subscriber_path(subscribers(:active)), response.body
    assert_no_match subscriber_path(subscribers(:other_accounts)), response.body
  end

  test "show with nothing matching says so" do
    get search_path(q: "nobody-by-this-name")

    assert_listed
    assert_match "No matches", response.body
  end

  test "show with no query lists nothing" do
    get search_path

    assert_response :success
    assert_listed
    assert_no_match "No matches", response.body
  end

  test "show as JSON lists the same records" do
    get search_path(q: subscribers(:bounced).email.first(3)), as: :json

    assert_response :success
    assert_equal accounts(:davids_account).posts.matching(subscribers(:bounced).email.first(3), account: accounts(:davids_account)).ids.sort, response.parsed_body["posts"].pluck("id").sort
    assert_equal [ subscribers(:bounced).id ], response.parsed_body["subscribers"].pluck("id")
  end

  test "show as JSON lists the posts whose text matches" do
    get search_path(q: "insurance"), as: :json

    assert_equal [ posts(:scheduled).id ], response.parsed_body["posts"].pluck("id")
  end

  test "show pages the subscribers and lists the posts whole" do
    16.times { |index| accounts(:davids_account).subscribers.create!(email: "paged#{index}@example.org") }
    posts(:draft).update! title: "Paged"

    get search_path(q: "paged")

    assert_match edit_post_path(posts(:draft)), response.body
    assert_select "a[href=?]", search_path(q: "paged", page: 2), count: 1

    get search_path(q: "paged", page: 2)

    assert_select "a[href=?]", search_path(q: "paged", page: 3), count: 0
  end

  private
    def assert_listed(*listed)
      accounts(:davids_account).posts.each do |post|
        if listed.include?(post)
          assert_match edit_post_path(post), response.body
        else
          assert_no_match edit_post_path(post), response.body
        end
      end
    end
end
