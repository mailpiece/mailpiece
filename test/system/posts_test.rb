require "application_system_test_case"

class PostsTest < ApplicationSystemTestCase
  test "open a draft from the posts list" do
    sign_in_as(users(:mia))

    visit posts_url
    click_on posts(:draft).title

    assert_field "post_title", with: posts(:draft).title
  end

  test "open a scheduled post from the posts list" do
    sign_in_as(users(:mia))

    visit posts_url
    click_on posts(:scheduled).title

    assert_field "post_title", with: posts(:scheduled).title
  end
end
