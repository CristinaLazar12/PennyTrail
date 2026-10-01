require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @expense = expenses(:one)
    @original_api_key = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "test-key"
  end

  teardown do
    ENV["GEMINI_API_KEY"] = @original_api_key
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
          category: "Dining Out"
        }
      }
    end

    expense = Expense.order(:id).last

    assert_equal "Dining Out", expense.category
    assert_nil expense.ai_category
    assert_redirected_to expenses_url
  end

  test "does not create an expense with invalid attributes" do
    assert_no_difference("Expense.count") do
      post expenses_url, params: {
        expense: {
          description: "Dinner",
          amount: "0",
          spent_on: Date.current,
          category: "Dining Out"
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

  test "should delete expense" do
    assert_difference("Expense.count", -1) do
      delete expense_url(@expense)
    end

    assert_redirected_to expenses_url
  end

  test "creates an expense with a corrected AI category" do
    token = Rails.application.message_verifier(:ai_suggestion).generate(
      {
        "category" => "Dining Out",
        "description" => "Dinner with a show",
        "amount" => "120.5"
      },
      expires_in: 1.hour
    )

    assert_difference("Expense.count", 1) do
      post expenses_url, params: {
        expense: {
          description: "Dinner with a show",
          amount: "120.50",
          spent_on: Date.current,
          category: "Entertainment"
        },
        ai_suggestion_token: token
      }
    end

    expense = Expense.order(:id).last

    assert_equal "Dining Out", expense.ai_category
    assert_equal "Entertainment", expense.category
    assert_redirected_to expenses_url
  end

  test "displays an AI suggestion without saving an expense" do
        fake_response = {
            candidates: [
                {
                    content: {
                        parts: [
                            { text: "Dining Out" }
                        ]
                    }
                }
            ]
        }

        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: fake_response.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        assert_no_difference("Expense.count") do
            post suggest_category_expenses_url, params: {
                expense: {
                    description: "Dinner at restaurant",
                    amount: "120.50",
                    spent_on: Date.current,
                    category: ""
                }
            }
        end

        assert_response :success
        assert_equal "text/vnd.turbo-stream.html", response.media_type
        assert_includes response.body, 'action="replace"'
        assert_includes response.body, 'target="expense_form"'
    end

  test "does not save the AI suggestion when the amount changes" do
      token = Rails.application.message_verifier(:ai_suggestion).generate(
        {
          "category" => "Dining Out",
          "description" => "Dinner at restaurant",
          "amount" => "120.5"
        },
        expires_in: 1.hour
      )

      assert_difference("Expense.count", 1) do
        post expenses_url, params: {
          expense: {
            description: "Dinner at restaurant",
            amount: "150.00",
            spent_on: Date.current,
            category: "Entertainment"
          },
          ai_suggestion_token: token
        }
      end

      expense = Expense.order(:id).last

      assert_equal "Entertainment", expense.category
      assert_nil expense.ai_category
      assert_redirected_to expenses_url
  end

  test "does not save the AI suggestion when the description changes" do
      token = Rails.application.message_verifier(:ai_suggestion).generate(
        {
          "category" => "Dining Out",
          "description" => "Dinner at restaurant",
          "amount" => "120.5"
        },
        expires_in: 1.hour
      )

      assert_difference("Expense.count", 1) do
        post expenses_url, params: {
          expense: {
            description: "Cinema tickets",
            amount: "120.50",
            spent_on: Date.current,
            category: "Entertainment"
          },
          ai_suggestion_token: token
        }
      end

      expense = Expense.order(:id).last

      assert_equal "Entertainment", expense.category
      assert_nil expense.ai_category
      assert_redirected_to expenses_url
  end

  test "creates an expense with an accepted AI category" do
    token = Rails.application.message_verifier(:ai_suggestion).generate(
      {
        "category" => "Dining Out",
        "description" => "Dinner with a show",
        "amount" => "120.5"
      },
      expires_in: 1.hour
    )

    assert_difference("Expense.count", 1) do
      post expenses_url, params: {
        expense: {
          description: "Dinner with a show",
          amount: "120.50",
          spent_on: Date.current,
          category: "Dining Out"
        },
        ai_suggestion_token: token
      }
    end

    expense = Expense.order(:id).last

    assert_equal "Dining Out", expense.ai_category
    assert_equal "Dining Out", expense.category
    assert_redirected_to expenses_url
  end

  test "shows a helpful message when AI is unavailable" do
    stub_request(
      :post,
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
    ).to_return(
      status: 503,
      body: '{"error":{"message":"Unavailable"}}',
      headers: { "Content-Type" => "application/json" }
    )

    assert_no_difference("Expense.count") do
      post suggest_category_expenses_url, params: {
        expense: {
          description: "Dinner at restaurant",
          amount: "120.50",
          spent_on: Date.current,
          category: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.text,
      "We couldn't suggest a category. Please choose one manually."

    assert_difference("Expense.count", 1) do
      post expenses_url, params: {
        expense: {
          description: "Dinner at restaurant",
          amount: "120.50",
          spent_on: Date.current,
          category: "Dining Out"
        }
      }
    end

    expense = Expense.order(:id).last

    assert_equal "Dining Out", expense.category
    assert_nil expense.ai_category
    assert_redirected_to expenses_url
  end

  test "clears the AI suggestion when an expense description is updated" do
    @expense.update!(
      description: "Dinner at restaurant",
      category: "Entertainment",
      ai_category: "Dining Out"
    )

    patch expense_url(@expense), params: {
      expense: {
        description: "Cinema tickets"
      }
    }

    @expense.reload

    assert_equal "Cinema tickets", @expense.description
    assert_equal "Entertainment", @expense.category
    assert_nil @expense.ai_category
    assert_redirected_to expense_url(@expense)
  end

  test "clears the AI suggestion when an expense amount is updated" do
    @expense.update!(
      description: "Dinner at restaurant",
      amount: "120.50",
      category: "Entertainment",
      ai_category: "Dining Out"
    )

    patch expense_url(@expense), params: {
      expense: {
        amount: "150.00"
      }
    }

    @expense.reload

    assert_equal BigDecimal("150.00"), @expense.amount
    assert_equal "Entertainment", @expense.category
    assert_nil @expense.ai_category
    assert_redirected_to expense_url(@expense)
  end

  test "keeps the AI suggestion when only the final category is updated" do
    @expense.update!(
      category: "Dining Out",
      ai_category: "Dining Out"
    )

    patch expense_url(@expense), params: {
      expense: {
        category: "Entertainment"
      }
    }

    @expense.reload

    assert_equal "Entertainment", @expense.category
    assert_equal "Dining Out", @expense.ai_category
    assert_redirected_to expense_url(@expense)
  end
end
