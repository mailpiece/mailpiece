require "test_helper"

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test "sends an admin to the posts" do
    sign_in_as :mia

    get landing_path

    assert_redirected_to posts_path
  end

  test "a member stays" do
    sign_in_as :nonstaff

    get landing_path

    assert_response :success
  end
end
