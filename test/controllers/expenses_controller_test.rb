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

  test "creates an expense with valid attributes" do
    assert_difference("Expense.count", 1) do
      post expenses_url, params: {
        expense: {
          description: "Dinner",
          amount: "45.50",
          spent_on: Date.current,
          category: "Food"
        }
      }
    end

    assert_redirected_to expenses_url
  end

  test "does not create an expense with invalid attributes" do
    assert_no_difference("Expense.count") do
      post expenses_url, params: {
        expense: {
          description: "Dinner",
          amount: "0",
          spent_on: Date.current,
          category: "Food"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "li", text: "Amount must be greater than 0"
    assert_select 'input[name="expense[description]"][value="Dinner"]'
    assert_select 'input[name="expense[category]"][value="Food"]'
    assert_select 'input[name="expense[amount]"]' do |inputs|
      assert_equal BigDecimal("0"), BigDecimal(inputs.first["value"])
    end
    assert_select 'input[name="expense[spent_on]"]' do |inputs|
      assert_equal Date.current.to_s, inputs.first["value"]
    end
  end
end
