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
    # TKTK -- implement when parameter forms are added
  end

  def show
    @report = Report.find(params[:id])
  end
end