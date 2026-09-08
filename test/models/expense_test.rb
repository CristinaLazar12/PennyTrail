require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  test "expense is valid with all the required attributes" do
    expense = Expense.new(
      description: "Dinner at restaurant",
      amount: "120.50",
      spent_on: Date.current,
      category: "Food"
    )

    assert expense.valid?, expense.errors.full_messages.join(", ")
  end

  test "expense is not valid with a 0 amount" do
    expense = Expense.new(
      description: "Dinner at restaurant",
      amount: "0",
      spent_on: Date.current,
      category: "Food"
    )

    assert_not expense.valid?
    assert expense.errors.of_kind?(:amount, :greater_than)
  end
end
