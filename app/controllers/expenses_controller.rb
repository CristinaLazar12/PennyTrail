class ExpensesController < ApplicationController
  def index
    @expenses = Expense.order(spent_on: :desc, id: :desc)
  end

  def new
    @expense = Expense.new
  end

  def create
    @expense = Expense.new(expense_params)

    suggestion = verified_ai_suggestion

    if suggestion.present? &&
        suggestion["description"] == @expense.description &&
        suggestion["amount"] == @expense.amount&.to_s("F")
      @expense.ai_category = suggestion["category"]
      @ai_suggestion_token = params[:ai_suggestion_token]
    end

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
    @expense.assign_attributes(expense_params)

    if @expense.will_save_change_to_description? ||
        @expense.will_save_change_to_amount?
      @expense.ai_category = nil
    end

    if @expense.save
      redirect_to expense_path(@expense), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense = Expense.find(params[:id])
    @expense.destroy

    redirect_to expenses_path, notice: "Expense was successfully deleted.",
      status: :see_other
  end

  def suggest_category
    @expense = Expense.new(expense_params)

    if @expense.description.blank? || @expense.amount.nil? || @expense.amount <= 0
      @expense.errors.add(
        :base,
        "Enter a description and a positive amount before requesting a suggestion."
      )

      return render :new, status: :unprocessable_entity
    end

    categorizer = ExpenseCategorizer.new(
      description: @expense.description,
      amount: @expense.amount
    )

    @expense.ai_category = categorizer.call

    @ai_suggestion_token = Rails.application.message_verifier(:ai_suggestion).generate(
      {
        "category" => @expense.ai_category,
        "description" => @expense.description,
        "amount" => @expense.amount.to_s("F")
      },
      expires_in: 1.hour
    )

    render turbo_stream: turbo_stream.replace(
      "expense_form",
      partial: "expenses/form"
    )
  rescue ExpenseCategorizer::Error => error
    Rails.logger.warn("AI suggestion failed: #{error.message}")

    @expense.errors.add(
      :base,
      "We couldn't suggest a category. Please choose one manually."
    )

    render :new, status: :unprocessable_entity
  end

  private

  def expense_params
    params.require(:expense).permit(
      :description, :spent_on, :category, :amount
    )
  end

  def verified_ai_suggestion
    return nil if params[:ai_suggestion_token].blank?

    Rails.application.message_verifier(:ai_suggestion).verified(
      params[:ai_suggestion_token]
    )
  end
end
