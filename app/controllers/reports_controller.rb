class ReportsController < ApplicationController
  require "csv"

  def new
    @user = User.find(params[:user_id])
    @report_type = params[:report_type]
    # redirect if invalid report type
    unless Report.report_types.key?(@report_type)
      redirect_to root_path, alert: "Invalid report type"
    end
  end

  def create
    @user = User.find(params[:user_id])
    @report_type = params[:report_type]

    if @report_type == "fte"
      # Get the parameters from the form
      incoming_requests = params[:incoming_requests_per_hour].to_f
      resolution_time = params[:average_resolution_time].to_f
      requests_per_employee = params[:requests_per_employee_per_hour].to_f

      # Calculate FTE: (incoming requests per hour * average resolution time) / requests per employee per hour
      fte_needed = (incoming_requests * resolution_time) / requests_per_employee

      # Create the report with parameters and results
      @report = Report.create!(
        user: @user,
        report_type: @report_type,
        parameters: {
          incoming_requests_per_hour: incoming_requests,
          average_resolution_time: resolution_time,
          requests_per_employee_per_hour: requests_per_employee
        },
        results: {
          fte_needed: fte_needed
        }
      )

      redirect_to report_path(@report)
    elsif @report_type == "erlang"
      # Get the parameters from the form
      call_volume = params[:call_volume].to_f
      aht = params[:average_handling_time].to_f
      service_level_target = params[:service_level_target].to_f / 100.0  # Convert percentage to decimal
      target_time = params[:target_time].to_f

      # Calculate traffic intensity (Erlangs)
      traffic_intensity = (call_volume * aht) / 3600.0  # Convert AHT from seconds to hours

      # Find minimum number of agents needed
      agents_needed = calculate_erlang_agents(traffic_intensity, service_level_target, target_time, aht)

      # Create the report with parameters and results
      @report = Report.create!(
        user: @user,
        report_type: @report_type,
        parameters: {
          call_volume: call_volume,
          average_handling_time: aht,
          service_level_target: service_level_target * 100,  # Store as percentage
          target_time: target_time
        },
        results: {
          agents_needed: agents_needed,
          traffic_intensity: traffic_intensity
        }
      )

      redirect_to report_path(@report)
    else
      redirect_to root_path, alert: "Invalid report type"
    end
  end

  def show
    @report = Report.find(params[:id])
  end

  def export_csv
    @report = Report.find(params[:id])

    if @report.report_type == "fte"
      # Extract parameters
      incoming_requests = @report.parameters["incoming_requests_per_hour"].to_f
      resolution_time = @report.parameters["average_resolution_time"].to_f
      requests_per_employee = @report.parameters["requests_per_employee_per_hour"].to_f

      # Generate CSV
      csv_data = CSV.generate(headers: true) do |csv|
        # Header information
        csv << [ "FTE Projection Report" ]
        csv << [ "User", @report.user.name ]
        csv << [ "Date", Date.today.strftime("%Y-%m-%d") ]
        csv << []

        # Parameters section
        csv << [ "Parameters:" ]
        csv << [ "Incoming requests per hour", incoming_requests ]
        csv << [ "Average resolution time per support request (hours)", resolution_time ]
        csv << [ "Requests completed per employee per hour", requests_per_employee ]
        csv << []

        # Baseline result
        csv << [ "Baseline Result:" ]
        csv << [ "FTE Needed", @report.results["fte_needed"].round(2) ]
        csv << []

        # Scenario Analysis Table
        csv << [ "Scenario Analysis:" ]
        csv << [
          "Multiplier",
          "Incoming Requests Only (others constant)",
          "Resolution Time Only (others constant)",
          "Productivity Only (others constant)",
          "Request & Resolution (productivity constant)",
          "Request, Resolution, & Productivity"
        ]

        # Calculate scenarios for each multiplier
        multipliers = [ 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 ]
        multipliers.each do |mult|
          fte_requests = (incoming_requests * mult * resolution_time) / requests_per_employee
          fte_resolution = (incoming_requests * resolution_time * mult) / requests_per_employee
          fte_productivity = (incoming_requests * resolution_time) / (requests_per_employee * mult)
          fte_request_resolution = (incoming_requests * mult * resolution_time * mult) / requests_per_employee
          fte_all_combined = (incoming_requests * mult * resolution_time * mult) / (requests_per_employee * mult)

          csv << [
            "#{mult}x",
            fte_requests.round(2),
            fte_resolution.round(2),
            fte_productivity.round(2),
            fte_request_resolution.round(2),
            fte_all_combined.round(2)
          ]
        end
      end

      # Generate filename
      filename = "FTE Projection Report by #{@report.user.name} on #{Date.today.strftime('%Y-%m-%d')}.csv"

      # Send CSV file
      send_data csv_data, filename: filename, type: "text/csv"
    elsif @report.report_type == "erlang"
      # Extract parameters
      call_volume = @report.parameters["call_volume"].to_f
      aht = @report.parameters["average_handling_time"].to_f
      service_level_target = @report.parameters["service_level_target"].to_f
      target_time = @report.parameters["target_time"].to_f

      # Generate CSV
      csv_data = CSV.generate(headers: true) do |csv|
        # Header information
        csv << [ "Erlang C Staffing Model Report" ]
        csv << [ "User", @report.user.name ]
        csv << [ "Date", Date.today.strftime("%Y-%m-%d") ]
        csv << []

        # Parameters section
        csv << [ "Parameters:" ]
        csv << [ "Call volume (calls per hour)", call_volume ]
        csv << [ "Average Handling Time (seconds)", aht ]
        csv << [ "Service Level Target (%)", service_level_target ]
        csv << [ "Target Time (seconds)", target_time ]
        csv << []

        # Baseline result
        csv << [ "Baseline Result:" ]
        csv << [ "Agents Needed", @report.results["agents_needed"] ]
        csv << [ "Traffic Intensity (Erlangs)", @report.results["traffic_intensity"].round(2) ]
        csv << []

        # Scenario Analysis Table
        csv << [ "Scenario Analysis:" ]
        csv << [
          "Multiplier",
          "Call Volume Only (others constant)",
          "Avg Handling Time Only (others constant)",
          "Service Level Target Only (others constant)",
          "Target Time Only (others constant)",
          "All Combined"
        ]

        # Calculate scenarios for each multiplier
        multipliers = [ 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 ]
        step_size = (100.0 - service_level_target) / 8.0

        multipliers.each_with_index do |mult, index|
          # Calculate service level target for this row
          if mult == 0.5
            sl_target_for_row = [ service_level_target - 5, 0 ].max
          elsif mult == 1
            sl_target_for_row = service_level_target
          else
            step_number = index - 1
            sl_target_for_row = [ service_level_target + (step_size * step_number), 100 ].min
          end

          # Calculate traffic intensity for each scenario
          traffic_call_volume = (call_volume * mult * aht) / 3600.0
          traffic_aht = (call_volume * aht * mult) / 3600.0
          traffic_baseline = (call_volume * aht) / 3600.0
          traffic_combined = (call_volume * mult * aht * mult) / 3600.0

          # Calculate agents for each scenario
          agents_call_volume = calculate_erlang_agents(traffic_call_volume, service_level_target / 100.0, target_time, aht)
          agents_aht = calculate_erlang_agents(traffic_aht, service_level_target / 100.0, target_time, aht * mult)
          agents_sl_target = calculate_erlang_agents(traffic_baseline, sl_target_for_row / 100.0, target_time, aht)
          agents_target_time = calculate_erlang_agents(traffic_baseline, service_level_target / 100.0, target_time * mult, aht)
          agents_combined = calculate_erlang_agents(traffic_combined, sl_target_for_row / 100.0, target_time * mult, aht * mult)

          csv << [
            "#{mult}x",
            agents_call_volume,
            agents_aht,
            "#{agents_sl_target} (SL: #{sl_target_for_row.round(1)}%)",
            agents_target_time,
            agents_combined
          ]
        end
      end

      # Generate filename
      filename = "Erlang C Staffing Model Report by #{@report.user.name} on #{Date.today.strftime('%Y-%m-%d')}.csv"

      # Send CSV file
      send_data csv_data, filename: filename, type: "text/csv"
    else
      redirect_to report_path(@report), alert: "CSV export is not available for this report type"
    end
  end

  private

  # Include helper methods for Erlang calculations
  include ApplicationHelper
end
