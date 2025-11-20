require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "should not save report without report_type" do
    user = User.create!(name: "Test User")
    report = Report.new(user: user)
    assert_not report.save, "Saved the report without a report_type"
  end

  test "should not save report without user" do
    report = Report.new(report_type: "fte")
    assert_not report.save, "Saved the report without a user"
  end

  test "should save report with valid attributes" do
    user = User.create!(name: "Test User")
    report = Report.new(user: user, report_type: "fte", name: "Test Report")
    assert report.save, "Failed to save a valid report"
  end

  test "should belong to user" do
    report = Report.reflect_on_association(:user)
    assert_equal :belongs_to, report.macro
  end

  test "should accept valid report_type fte" do
    user = User.create!(name: "Test User")
    report = Report.new(user: user, report_type: "fte")
    assert report.valid?, "Report with type 'fte' should be valid"
  end

  test "should accept valid report_type erlang" do
    user = User.create!(name: "Test User")
    report = Report.new(user: user, report_type: "erlang")
    assert report.valid?, "Report with type 'erlang' should be valid"
  end

  test "should have correct report_types enum" do
    expected_types = { "fte" => "fte", "erlang" => "erlang" }
    assert_equal expected_types, Report.report_types
  end

  test "to_csv should return empty string when results is blank" do
    user = User.create!(name: "Test User")
    report = Report.create!(user: user, report_type: "fte", results: nil)
    assert_equal "", report.to_csv
  end

  test "to_csv should return empty string when results is empty hash" do
    user = User.create!(name: "Test User")
    report = Report.create!(user: user, report_type: "fte", results: {})
    assert_equal "", report.to_csv
  end

  test "to_csv should generate CSV with columns and rows" do
    user = User.create!(name: "Test User")
    results = {
      "columns" => [ "Name", "Value", "Status" ],
      "rows" => [
        [ "Item 1", "100", "Active" ],
        [ "Item 2", "200", "Inactive" ]
      ]
    }
    report = Report.create!(user: user, report_type: "fte", results: results)

    csv_output = report.to_csv
    lines = csv_output.split("\n")

    assert_equal "Name,Value,Status", lines[0]
    assert_equal "Item 1,100,Active", lines[1]
    assert_equal "Item 2,200,Inactive", lines[2]
  end

  test "to_csv should handle empty rows array" do
    user = User.create!(name: "Test User")
    results = {
      "columns" => [ "Name", "Value" ],
      "rows" => []
    }
    report = Report.create!(user: user, report_type: "fte", results: results)

    csv_output = report.to_csv
    lines = csv_output.split("\n").reject(&:empty?)

    assert_equal 1, lines.length
    assert_equal "Name,Value", lines[0]
  end

  test "to_csv should handle special characters in data" do
    user = User.create!(name: "Test User")
    results = {
      "columns" => [ "Name", "Description" ],
      "rows" => [
        [ "Test, Item", "Description with \"quotes\"" ]
      ]
    }
    report = Report.create!(user: user, report_type: "fte", results: results)

    csv_output = report.to_csv
    assert_includes csv_output, "\"Test, Item\""
    assert_includes csv_output, "\"Description with \"\"quotes\"\"\""
  end

  test "should store FTE parameters correctly" do
    user = User.create!(name: "Test User")
    parameters = {
      incoming_requests_per_hour: 100,
      average_resolution_time: 0.5,
      requests_per_employee_per_hour: 5
    }
    report = Report.create!(
      user: user,
      report_type: "fte",
      parameters: parameters
    )

    assert_equal 100, report.parameters["incoming_requests_per_hour"]
    assert_equal 0.5, report.parameters["average_resolution_time"]
    assert_equal 5, report.parameters["requests_per_employee_per_hour"]
  end

  test "should store FTE results correctly" do
    user = User.create!(name: "Test User")
    results = { fte_needed: 10.5 }
    report = Report.create!(
      user: user,
      report_type: "fte",
      results: results
    )

    assert_equal 10.5, report.results["fte_needed"]
  end

  test "should store both FTE parameters and results" do
    user = User.create!(name: "Test User")
    parameters = {
      incoming_requests_per_hour: 75,
      average_resolution_time: 1.2,
      requests_per_employee_per_hour: 4
    }
    results = { fte_needed: 22.5 }

    report = Report.create!(
      user: user,
      report_type: "fte",
      parameters: parameters,
      results: results
    )

    assert_equal 75, report.parameters["incoming_requests_per_hour"]
    assert_equal 1.2, report.parameters["average_resolution_time"]
    assert_equal 4, report.parameters["requests_per_employee_per_hour"]
    assert_equal 22.5, report.results["fte_needed"]
  end

  test "should handle FTE report with zero result" do
    user = User.create!(name: "Test User")
    results = { fte_needed: 0.0 }
    report = Report.create!(
      user: user,
      report_type: "fte",
      results: results
    )

    assert_equal 0.0, report.results["fte_needed"]
  end

  test "should handle FTE report with fractional result" do
    user = User.create!(name: "Test User")
    results = { fte_needed: 3.14159 }
    report = Report.create!(
      user: user,
      report_type: "fte",
      results: results
    )

    assert_equal 3.14159, report.results["fte_needed"]
  end
end
