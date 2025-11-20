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

  # Erlang C Tests

  test "should create Erlang report with valid parameters" do
    user = users(:one)

    assert_difference("Report.count") do
      post reports_url, params: {
        user_id: user.id,
        report_type: "erlang",
        call_volume: 100,
        average_handling_time: 180,  # 3 minutes in seconds
        service_level_target: 80,
        target_time: 20
      }
    end

    report = Report.last
    assert_equal "erlang", report.report_type
    assert_equal user.id, report.user_id
    assert_equal 100.0, report.parameters["call_volume"]
    assert_equal 180.0, report.parameters["average_handling_time"]
    assert_equal 80.0, report.parameters["service_level_target"]
    assert_equal 20.0, report.parameters["target_time"]

    assert_redirected_to report_path(report)
  end

  test "should calculate Erlang agents correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 100,
      average_handling_time: 180,  # 3 minutes
      service_level_target: 80,
      target_time: 20
    }

    report = Report.last

    # With 100 calls/hour and 180 seconds AHT, traffic intensity = (100 * 180) / 3600 = 5 Erlangs
    expected_traffic_intensity = (100.0 * 180.0) / 3600.0
    assert_in_delta expected_traffic_intensity, report.results["traffic_intensity"], 0.01

    # Agents needed should be at least the traffic intensity
    assert report.results["agents_needed"] >= expected_traffic_intensity.ceil
    assert report.results["agents_needed"].is_a?(Integer)
  end

  test "should calculate Erlang with high service level requirement" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 50,
      average_handling_time: 240,  # 4 minutes
      service_level_target: 95,  # High service level
      target_time: 15  # Short target time
    }

    report = Report.last

    # Higher service level and shorter target time should require more agents
    traffic_intensity = (50.0 * 240.0) / 3600.0
    assert report.results["agents_needed"] > traffic_intensity.ceil
  end

  test "should calculate Erlang with low traffic" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 10,
      average_handling_time: 120,
      service_level_target: 80,
      target_time: 20
    }

    report = Report.last

    traffic_intensity = (10.0 * 120.0) / 3600.0  # Should be ~0.33 Erlangs
    assert_in_delta traffic_intensity, report.results["traffic_intensity"], 0.01

    # Even with low traffic, should need at least 1 agent
    assert report.results["agents_needed"] >= 1
  end

  test "should handle Erlang with different service level targets" do
    user = users(:one)

    # Test with 70% service level
    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 100,
      average_handling_time: 180,
      service_level_target: 70,
      target_time: 20
    }
    report_70 = Report.last

    # Test with 90% service level
    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 100,
      average_handling_time: 180,
      service_level_target: 90,
      target_time: 20
    }
    report_90 = Report.last

    # Higher service level should require more agents
    assert report_90.results["agents_needed"] >= report_70.results["agents_needed"]
  end

  test "should calculate traffic intensity correctly" do
    user = users(:one)

    # Test case: 60 calls/hour, 300 seconds AHT
    # Expected: (60 * 300) / 3600 = 5.0 Erlangs
    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 60,
      average_handling_time: 300,
      service_level_target: 80,
      target_time: 20
    }

    report = Report.last
    expected_traffic = (60.0 * 300.0) / 3600.0
    assert_in_delta expected_traffic, report.results["traffic_intensity"], 0.001
  end
end
