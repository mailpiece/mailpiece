require "test_helper"

class Public::RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @delivery = post_deliveries(:sent_to_active)
    @token = @delivery.generate_token_for(:rating)
  end

  test "new offers the choice from the link, links to the other, and records nothing" do
    get new_public_rating_path(access_token: @token, choice: "liked")

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "p", text: /\ATell me what you thought of “Three deadlines in March/
    assert_select "form[action=?]", public_rating_path(access_token: @token) do
      assert_select "input[type=hidden][name=choice][value=liked]"
      assert_select "button", text: "I liked it"
    end
    assert_select "a[href=?]", new_public_rating_path(access_token: @token, choice: "disliked"), text: "or: it wasn't for me"
    assert_empty posts(:sent).ratings
  end

  test "new of a choice that is neither is not found" do
    get new_public_rating_path(access_token: @token, choice: "loved it")
    assert_response :not_found
  end

  test "create records the choice for the delivery's subscriber and goes to the thanks" do
    post public_rating_path(access_token: @token), params: { choice: "disliked" }

    assert_redirected_to public_rating_path(access_token: @token)
    assert_includes response.headers["Cache-Control"], "no-store"
    assert posts(:sent).ratings.find_by!(subscriber: subscribers(:active)).disliked?
  end

  test "show says thanks and records nothing" do
    get public_rating_path(access_token: @token)

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "h1", text: "Thanks, noted."
    assert_empty posts(:sent).ratings
  end

  test "create again changes the choice" do
    %w[ liked disliked ].each do |choice|
      post public_rating_path(access_token: @token), params: { choice: choice }
    end

    assert posts(:sent).ratings.sole.disliked?
  end

  test "a delivery whose mail is unverified may rate" do
    @delivery.update!(sent_at: nil, claimed_at: 1.hour.ago)

    post public_rating_path(access_token: @token), params: { choice: "liked" }

    assert_redirected_to public_rating_path(access_token: @token)
    assert posts(:sent).ratings.sole.liked?
  end

  test "a wrong or missing token goes to the newsletter" do
    get new_public_rating_path(access_token: "nope", choice: "liked")
    assert_redirected_to root_path

    post public_rating_path, params: { choice: "liked" }
    assert_redirected_to root_path

    get public_rating_path(access_token: "nope")
    assert_redirected_to root_path

    assert_empty Post::Rating.all
  end

  test "a token a month old goes to the newsletter" do
    travel 1.month + 1.day

    get new_public_rating_path(access_token: @token, choice: "liked")
    assert_redirected_to root_path
  end

  test "a token for another purpose goes to the newsletter" do
    get new_public_rating_path(access_token: subscribers(:active).token, choice: "liked")
    assert_redirected_to root_path
  end

  test "a delivery of another account goes to the newsletter" do
    other = Post::Delivery.create!(post: posts(:other_accounts), subscriber: subscribers(:other_accounts), deliver_at: Time.current, sent_at: Time.current)

    get new_public_rating_path(access_token: other.generate_token_for(:rating), choice: "liked")
    assert_redirected_to root_path
  end
end
