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

  test "should create FTE report with valid parameters" do
    user = users(:one)

    assert_difference("Report.count") do
      post reports_url, params: {
        user_id: user.id,
        report_type: "fte",
        incoming_requests_per_hour: 100,
        average_resolution_time: 0.5,
        requests_per_employee_per_hour: 5
      }
    end

    report = Report.last
    assert_equal "fte", report.report_type
    assert_equal user.id, report.user_id
    assert_equal 100.0, report.parameters["incoming_requests_per_hour"]
    assert_equal 0.5, report.parameters["average_resolution_time"]
    assert_equal 5.0, report.parameters["requests_per_employee_per_hour"]

    assert_redirected_to report_path(report)
  end

  test "should calculate FTE correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 0.5,
      requests_per_employee_per_hour: 5
    }

    report = Report.last
    expected_fte = (100.0 * 0.5) / 5.0  # = 10.0
    assert_equal expected_fte, report.results["fte_needed"]
  end

  test "should calculate FTE with decimal result" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 50,
      average_resolution_time: 0.75,
      requests_per_employee_per_hour: 3
    }

    report = Report.last
    expected_fte = (50.0 * 0.75) / 3.0  # = 12.5
    assert_equal expected_fte, report.results["fte_needed"]
  end

  test "should handle FTE calculation with zero requests" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 0,
      average_resolution_time: 0.5,
      requests_per_employee_per_hour: 5
    }

    report = Report.last
    expected_fte = (0.0 * 0.5) / 5.0  # = 0.0
    assert_equal expected_fte, report.results["fte_needed"]
  end

  test "should redirect to root with invalid report_type on create" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "invalid_type",
      incoming_requests_per_hour: 100,
      average_resolution_time: 0.5,
      requests_per_employee_per_hour: 5
    }

    assert_redirected_to root_path
    assert_equal "Invalid report type", flash[:alert]
  end

  test "should get show with valid report" do
    report = reports(:fte_report)
    get report_url(report)
    assert_response :success
  end
end
