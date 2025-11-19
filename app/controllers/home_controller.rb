class HomeController < ApplicationController
  def index
    @users = User.all
    @report_types = Report.report_types.keys
  end
end
