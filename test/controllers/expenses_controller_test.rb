require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  test "index displays an expense" do
    Expense.create!(
      description: "Lunch at cafe",
      amount: "45.50",
      spent_on: Date.current,
      category: "Food"
    )

    get expenses_url

    assert_response :success
    assert_select "h2", text: "Lunch at cafe"
    assert_select "p", text: "RON 45.50"
  end
end
