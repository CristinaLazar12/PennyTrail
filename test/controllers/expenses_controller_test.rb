require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @expense = expenses(:one)
  end

  test "should get index" do
    get expenses_url

    assert_response :success
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
  end

  test "should show expense" do
    get expense_url(@expense)

    assert_response :success
  end

  test "show returns 404 error for unknown expense" do
    missing_id = (Expense.maximum(:id) || 0) + 1

    get expense_url(missing_id)

    assert_response :not_found
  end

  test "should get edit" do
    get edit_expense_url(@expense)

    assert_response :success
  end

  test "should update expense" do
    patch expense_url(@expense), params: {
      expense: {
        description: "Dinner"
      }
    }

    @expense.reload

    assert_equal "Dinner", @expense.description
    assert_redirected_to expense_url(@expense)
  end

  test "should not update with invalid amount" do
    original_amount = @expense.amount

    patch expense_url(@expense), params: {
      expense: {
        amount: "0"
      }
    }

    assert_response :unprocessable_entity
    @expense.reload
    assert_equal original_amount, @expense.amount
  end
end
