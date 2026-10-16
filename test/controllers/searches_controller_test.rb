require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    Post.find_each(&:reindex)
    sign_in_as :mia
  end

  test "show lists the posts whose title matches, whatever their state" do
    get search_path(q: "MARCH")

    assert_select "h1", text: /Search results for “MARCH”/
    assert_select "input[name=q][value=MARCH]"
    assert_select ".rows__heading", text: "Posts"
    assert_select "li##{dom_id(posts(:sent))} .row__meta", text: /\ASent to 2 subscribers on/
    assert_select "li##{dom_id(posts(:unlisted))}"
    assert_select "li##{dom_id(posts(:draft))}", count: 0
  end

  test "show lists the posts whose text matches" do
    get search_path(q: "insurance")

    assert_select "li##{dom_id(posts(:scheduled))}"
    assert_select "li.row", count: 1
  end

  test "show lists the posts that match part of a word" do
    get search_path(q: "Marc")

    assert_select "li##{dom_id(posts(:sent))}"
    assert_select "li##{dom_id(posts(:unlisted))}"
  end

  test "show with a term under three letters lists no post" do
    get search_path(q: "Ma")

    assert_select "li##{dom_id(posts(:sent))}", count: 0
  end

  test "show reads a word the index would take for an operator as a word" do
    get search_path(q: "NOT")

    assert_response :success
    assert_select "li##{dom_id(posts(:unlisted))}"

    get search_path(q: "cats AND")

    assert_response :success
    assert_select "li.row", count: 0
  end

  test "show reads a query with a stray quote or punctuation as its words" do
    get search_path(q: %(the "insurance?))

    assert_select "li##{dom_id(posts(:scheduled))}"
    assert_select "li.row", count: 1
  end

  test "show lists the posts whose summary matches" do
    posts(:draft).update! summary: "A checklist for the auditor"

    get search_path(q: "checklist")

    assert_select "li##{dom_id(posts(:draft))}"
    assert_select "li.row", count: 1
  end

  test "show finds a word whatever its accents" do
    posts(:draft).update! body: "<p>La inspección empieza por el seguro.</p>"

    get search_path(q: "inspeccion")
    assert_select "li##{dom_id(posts(:draft))}"

    posts(:draft).update! body: "<p>La inspeccion empieza por el seguro.</p>"

    get search_path(q: "inspección")
    assert_select "li##{dom_id(posts(:draft))}"
  end

  test "show finds what a box keeps for the web and not what one keeps for the email" do
    posts(:draft).update! body: %(<p>Hello.</p><aside data-audience="email"><p>Reply to this letter.</p></aside><aside data-audience="web"><p>Subscribe on the site.</p></aside>)

    get search_path(q: "subscribe on the site")
    assert_select "li##{dom_id(posts(:draft))}"

    get search_path(q: "letter")
    assert_select "li.row", count: 0
  end

  test "show stops finding a post by the text it no longer has" do
    posts(:scheduled).update! body: "<p>Rewritten.</p>"

    get search_path(q: "insurance")

    assert_select "li.row", count: 0
  end

  test "show never lists another account's post" do
    get search_path(q: "another account")

    assert_select "li.row", count: 0
  end

  test "show lists the addresses that match, whatever their state" do
    get search_path(q: subscribers(:bounced).email.first(3).upcase)

    assert_select ".rows__heading", text: "Subscribers"
    assert_select "li##{dom_id(subscribers(:bounced))} .row__meta", text: /\ABounced/
    assert_select "li##{dom_id(subscribers(:active))}", count: 0
  end

  test "show with nothing matching says so" do
    get search_path(q: "nobody-by-this-name")

    assert_select "li.row", count: 0
    assert_select ".blank-slate", text: "No matches"
  end

  test "show with no query lists nothing" do
    get search_path

    assert_select "li.row", count: 0
    assert_select ".blank-slate", count: 0
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

    assert_select "[data-controller=pagination][data-pagination-paginate-on-intersection-value=true]"
    assert_equal %w[ Posts Subscribers ], css_select(".rows__heading").map(&:text)
    assert_select ".subscribers li.row", count: 15
    assert_select "li.row", count: 16
    assert_select "a.pagination-link[href=?]", search_path(q: "paged", page: 2)

    get search_path(q: "paged", page: 2)

    assert_select ".subscribers li.row", count: 1
  end
end
