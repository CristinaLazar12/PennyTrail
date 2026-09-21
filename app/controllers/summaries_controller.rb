class SummariesController < ApplicationController
    def show
        if params[:month].present?
            @month_start = Date.strptime(params[:month], "%Y-%m")
        else
            @month_start = Date.current.beginning_of_month
        end

        month_end = @month_start.end_of_month
        monthly_expenses = Expense.where(spent_on: @month_start..month_end)

        @total = monthly_expenses.sum(:amount)
        @totals_by_category = monthly_expenses.group(:category).sum(:amount)
    rescue Date::Error
        render plain: "Invalid month. Use YYYY-MM.", status: :bad_request
    end
end
