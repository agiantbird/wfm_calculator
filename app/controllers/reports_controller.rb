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
    else
      redirect_to report_path(@report), alert: "CSV export is only available for FTE reports"
    end
  end

  private

  # Calculate minimum number of agents needed for Erlang C model
  def calculate_erlang_agents(traffic_intensity, service_level_target, target_time, aht)
    # Start with minimum agents = ceiling of traffic intensity
    agents = traffic_intensity.ceil
    max_agents = (traffic_intensity * 3).ceil  # Safety limit

    # Iterate to find minimum agents that meet service level
    while agents <= max_agents
      service_level = calculate_service_level(traffic_intensity, agents, target_time, aht)

      if service_level >= service_level_target
        return agents
      end

      agents += 1
    end

    # If we couldn't find a solution, return the max we tried
    agents
  end

  # Calculate service level for given parameters
  def calculate_service_level(traffic_intensity, agents, target_time, aht)
    # Calculate Erlang C (probability of delay)
    prob_delay = erlang_c(traffic_intensity, agents)

    # Calculate probability call is answered within target time
    # Formula: 1 - (Prob_Delay * e^(-(agents - traffic) * target_time / AHT))
    agent_surplus = agents - traffic_intensity
    return 0.0 if agent_surplus <= 0

    exponential_term = Math.exp(-(agent_surplus * target_time) / aht)
    service_level = 1.0 - (prob_delay * exponential_term)

    service_level
  end

  # Erlang C formula: probability of delay
  def erlang_c(traffic_intensity, agents)
    return 1.0 if agents <= traffic_intensity

    # Calculate Erlang B first
    erlang_b = erlang_b_value(traffic_intensity, agents)

    # Erlang C formula
    numerator = agents * erlang_b
    denominator = agents - traffic_intensity * (1 - erlang_b)

    return 0.0 if denominator <= 0

    numerator / denominator
  end

  # Calculate Erlang B (used in Erlang C calculation)
  def erlang_b_value(traffic_intensity, agents)
    return 1.0 if agents == 0

    erlang_b = 1.0

    (1..agents).each do |n|
      erlang_b = (traffic_intensity * erlang_b) / (n + traffic_intensity * erlang_b)
    end

    erlang_b
  end
end
