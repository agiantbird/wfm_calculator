require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "should get new with valid user and report_type fte" do
    user = users(:one)
    get new_report_url(user_id: user.id, report_type: "fte")
    assert_response :success
  end

  test "should get new with valid user and report_type erlang" do
    user = users(:one)
    get new_report_url(user_id: user.id, report_type: "erlang")
    assert_response :success
  end

  test "should redirect to root with invalid report_type" do
    user = users(:one)
    get new_report_url(user_id: user.id, report_type: "invalid_type")
    assert_redirected_to root_path
    assert_equal "Invalid report type", flash[:alert]
  end
end
