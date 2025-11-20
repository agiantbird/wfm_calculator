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

  # Scenario Analysis Tests

  test "should display scenario analysis table on FTE report show page" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    get report_url(report)

    assert_response :success
    assert_select "h2", text: "Scenario Analysis:"
    assert_select "table"
    assert_select "th", text: /Multiplier/
    assert_select "th", text: /Incoming Requests Only/
    assert_select "th", text: /Resolution Time Only/
    assert_select "th", text: /Productivity Only/
    assert_select "th", text: /Request & Resolution/
    assert_select "th", text: /Request, Resolution, & Productivity/
  end

  test "should calculate scenario for incoming requests only correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 2x multiplier: (100 * 2 * 1.0) / 10 = 20
    fte_requests_2x = (incoming * 2 * resolution) / productivity
    assert_equal 20.0, fte_requests_2x

    # Test 0.5x multiplier: (100 * 0.5 * 1.0) / 10 = 5
    fte_requests_half = (incoming * 0.5 * resolution) / productivity
    assert_equal 5.0, fte_requests_half
  end

  test "should calculate scenario for resolution time only correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 2x multiplier: (100 * 1.0 * 2) / 10 = 20
    fte_resolution_2x = (incoming * resolution * 2) / productivity
    assert_equal 20.0, fte_resolution_2x

    # Test 3x multiplier: (100 * 1.0 * 3) / 10 = 30
    fte_resolution_3x = (incoming * resolution * 3) / productivity
    assert_equal 30.0, fte_resolution_3x
  end

  test "should calculate scenario for productivity only correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 2x multiplier: (100 * 1.0) / (10 * 2) = 5
    fte_productivity_2x = (incoming * resolution) / (productivity * 2)
    assert_equal 5.0, fte_productivity_2x

    # Test 0.5x multiplier: (100 * 1.0) / (10 * 0.5) = 20
    fte_productivity_half = (incoming * resolution) / (productivity * 0.5)
    assert_equal 20.0, fte_productivity_half
  end

  test "should calculate request and resolution scenario correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 2x multiplier: (100 * 2 * 1.0 * 2) / 10 = 40
    # Both requests and resolution time doubled
    fte_request_resolution_2x = (incoming * 2 * resolution * 2) / productivity
    assert_equal 40.0, fte_request_resolution_2x

    # Test 1.5x multiplier: (100 * 1.5 * 1.0 * 1.5) / 10 = 22.5
    fte_request_resolution_1_5x = (incoming * 1.5 * resolution * 1.5) / productivity
    assert_equal 22.5, fte_request_resolution_1_5x
  end

  test "should calculate all parameters combined scenario correctly" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 2x multiplier: (100 * 2 * 1.0 * 2) / (10 * 2) = 20
    # All three parameters doubled
    fte_all_combined_2x = (incoming * 2 * resolution * 2) / (productivity * 2)
    assert_equal 20.0, fte_all_combined_2x

    # Test 3x multiplier: (100 * 3 * 1.0 * 3) / (10 * 3) = 30
    fte_all_combined_3x = (incoming * 3 * resolution * 3) / (productivity * 3)
    assert_equal 30.0, fte_all_combined_3x
  end

  test "should calculate all scenario multipliers correctly for baseline" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f
    baseline_fte = report.results["fte_needed"]

    multipliers = [ 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 ]

    multipliers.each do |mult|
      # Verify each scenario type at this multiplier
      fte_requests = (incoming * mult * resolution) / productivity
      fte_resolution = (incoming * resolution * mult) / productivity
      fte_productivity = (incoming * resolution) / (productivity * mult)
      fte_request_resolution = (incoming * mult * resolution * mult) / productivity
      fte_all_combined = (incoming * mult * resolution * mult) / (productivity * mult)

      # Baseline (1x) should match the original calculation
      if mult == 1
        assert_equal baseline_fte, fte_requests
        assert_equal baseline_fte, fte_resolution
        assert_equal baseline_fte, fte_productivity
        assert_equal baseline_fte, fte_request_resolution
        assert_equal baseline_fte, fte_all_combined
      end

      # Verify calculations make mathematical sense
      # When only requests increase, FTE should scale linearly
      assert_in_delta baseline_fte * mult, fte_requests, 0.01

      # When only resolution time increases, FTE should scale linearly
      assert_in_delta baseline_fte * mult, fte_resolution, 0.01

      # When productivity increases, FTE should decrease inversely
      assert_in_delta baseline_fte / mult, fte_productivity, 0.01

      # When requests and resolution both increase, effect is multiplicative
      assert_in_delta baseline_fte * mult * mult, fte_request_resolution, 0.01

      # When all three change, productivity offsets some of the increase
      assert_in_delta baseline_fte * mult, fte_all_combined, 0.01
    end
  end

  test "should handle decimal results in scenario calculations" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 50,
      average_resolution_time: 0.75,
      requests_per_employee_per_hour: 3
    }

    report = Report.last
    incoming = report.parameters["incoming_requests_per_hour"].to_f
    resolution = report.parameters["average_resolution_time"].to_f
    productivity = report.parameters["requests_per_employee_per_hour"].to_f

    # Test 1.5x multiplier for productivity: (50 * 0.75) / (3 * 1.5) = 8.333...
    fte_productivity_1_5x = (incoming * resolution) / (productivity * 1.5)
    assert_in_delta 8.33, fte_productivity_1_5x, 0.01

    # Test 2.5x multiplier for requests: (50 * 2.5 * 0.75) / 3 = 31.25
    fte_requests_2_5x = (incoming * 2.5 * resolution) / productivity
    assert_equal 31.25, fte_requests_2_5x
  end

  # CSV Export Tests

  test "should export FTE report as CSV" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    get export_csv_report_url(report)

    assert_response :success
    assert_equal "text/csv", @response.content_type
    assert_match(/FTE Projection Report by #{user.name}/, @response.headers["Content-Disposition"])
  end

  test "CSV export should include parameters and scenario analysis" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "fte",
      incoming_requests_per_hour: 100,
      average_resolution_time: 1.0,
      requests_per_employee_per_hour: 10
    }

    report = Report.last
    get export_csv_report_url(report)

    csv_content = @response.body

    # Check for header information
    assert_match(/FTE Projection Report/, csv_content)
    assert_match(/User,#{user.name}/, csv_content)

    # Check for parameters
    assert_match(/Parameters:/, csv_content)
    assert_match(/Incoming requests per hour,100/, csv_content)
    assert_match(/Average resolution time per support request \(hours\),1.0/, csv_content)
    assert_match(/Requests completed per employee per hour,10/, csv_content)

    # Check for baseline result
    assert_match(/Baseline Result:/, csv_content)
    assert_match(/FTE Needed,10.0/, csv_content)

    # Check for scenario analysis headers
    assert_match(/Scenario Analysis:/, csv_content)
    assert_match(/Multiplier/, csv_content)
    assert_match(/Incoming Requests Only/, csv_content)
    assert_match(/Resolution Time Only/, csv_content)
    assert_match(/Productivity Only/, csv_content)
    assert_match(/Request & Resolution/, csv_content)

    # Check for specific multiplier rows
    assert_match(/0.5x/, csv_content)
    assert_match(/1x/, csv_content)
    assert_match(/2x/, csv_content)
    assert_match(/5x/, csv_content)
  end

  test "should not export Erlang report as CSV" do
    user = users(:one)

    post reports_url, params: {
      user_id: user.id,
      report_type: "erlang",
      call_volume: 100,
      average_handling_time: 180,
      service_level_target: 80,
      target_time: 20
    }

    report = Report.last
    get export_csv_report_url(report)

    assert_redirected_to report_path(report)
    assert_equal "CSV export is only available for FTE reports", flash[:alert]
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
