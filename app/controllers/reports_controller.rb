class ReportsController < ApplicationController
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
    else
      redirect_to root_path, alert: "Invalid report type"
    end
  end

  def show
    @report = Report.find(params[:id])
  end
end
