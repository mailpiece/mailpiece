require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "staff can access mission control jobs" do
    sign_in_as :leo

    untenanted do
      get "/admin/jobs"
    end

    assert_response :success
  end

  test "non-staff cannot access mission control jobs" do
    sign_in_as :nonstaff

    untenanted do
      get "/admin/jobs"
    end

    assert_response :forbidden
  end
end
