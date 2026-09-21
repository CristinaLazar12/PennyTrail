require "test_helper"

class SummariesControllerTest < ActionDispatch::IntegrationTest
  test "should get summary" do
    get summary_url

    assert_response :success
  end

  test "should reject an invalid month" do
    get summary_url, params: { month: "abc" }

    assert_response :bad_request
  end

  test "summary includes the expenses from the selected month" do
    september_expense = expenses(:one)
    august_expense = expenses(:two)

    september_expense.update!(
      spent_on: Date.new(2026, 9, 10),
      amount: 100
    )

    august_expense.update!(
      spent_on: Date.new(2026, 8, 10),
      amount: 50
    )

    get summary_url, params: { month: "2026-09" }

    assert_response :success
    assert_includes response.body, "RON 100.00"
    assert_not_includes response.body, "RON 50.00"
    assert_not_includes response.body, "RON 150.00"
  end

  test "summary displays 0 when the month has no expenses" do
    get summary_url, params: { month: "2026-02" }

    assert_response :success
    assert_includes response.body, "RON 0.00"
    assert_includes response.body, "No expenses for this month."
  end

  test "summary adds expenses from the same category" do
    first_expense = expenses(:one)
    second_expense = expenses(:two)

    first_expense.update!(
      spent_on: Date.new(2026, 9, 10),
      amount: 50,
      category: "Dining Out"
    )

    second_expense.update!(
      spent_on: Date.new(2026, 9, 20),
      amount: 100,
      category: "Dining Out"
    )

    get summary_url, params: { month: "2026-09" }
    assert_response :success
    assert_includes response.body, "Dining Out - RON 150.00"
  end

  test "summary excludes expenses from the previous year" do
    january2025_expense = expenses(:one)
    january2026_expense = expenses(:two)

    january2025_expense.update!(
      spent_on: Date.new(2025, 1, 1),
      amount: 50
    )

    january2026_expense.update!(
      spent_on: Date.new(2026, 1, 1),
      amount: 100
    )

    get summary_url, params: { month: "2026-01" }
    assert_response :success
    assert_includes response.body, "RON 100.00"
    assert_not_includes response.body, "RON 50.00"
    assert_not_includes response.body, "RON 150.00"
  end
end
