class ExpensesController < ApplicationController
  def index
    @expenses = Expense.order(spent_on: :desc, id: :desc)
  end

  def new
    @expense = Expense.new
  end

  def create
    @expense = Expense.new(expense_params)

    if @expense.save
      redirect_to expenses_url, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @expense = Expense.find(params[:id])
  end

  def edit
    @expense = Expense.find(params[:id])
  end

  def update
    @expense = Expense.find(params[:id])

    if @expense.update(expense_params)
      redirect_to expense_path(@expense), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def expense_params
    params.require(:expense).permit(
      :description, :spent_on, :category, :amount
    )
  end
end
