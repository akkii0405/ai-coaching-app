class DashboardsController < ApplicationController
  before_action :authenticate_user!
  def show
    @goals = current_user.goals
    @todays_tasks = current_user.tasks.where(due_date: Date.current)
  end
end