class ActivitiesController < ApplicationController
  WEEKS = 53

  def show
    @end_date   = Date.current
    @start_date = (@end_date - (WEEKS - 1).weeks).beginning_of_week(:sunday)
    @counts     = Current.user.activity_by_day_since(@start_date)
    @total      = @counts.values.sum
  end
end
