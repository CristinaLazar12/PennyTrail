require "test_helper"

class ExpenseCategorizerTest < ActiveSupport::TestCase
    setup do # setup rulează înaintea fiecărui test: păstrează valoarea existentă și pune "test-key" în locul ei.
        @original_api_key = ENV["GEMINI_API_KEY"]
        ENV["GEMINI_API_KEY"] = "test-key" # cheie fictivă pentru teste
      # "test-key" este doar un text pentru teste. WebMock va intercepta cererea, deci nu avem nevoie de o cheie reală
    end

    teardown do # teardown rulează după fiecare test: restaurează valoarea inițială. Dacă nu exista, variabila este eliminată
        ENV["GEMINI_API_KEY"] = @original_api_key
    end

    test "returns the category received from Gemini" do
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: fake_response.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        assert_equal "Dining Out", categorizer.call
    end

    test "rejects an unsupported category" do
        fake_response = {
            candidates: [
                {
                    content: {
                        parts: [
                            { text: "Unknown" }
                        ]
                    }
                }
            ]
        }

        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: fake_response.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        assert_raises(RuntimeError) do
            categorizer.call
        end
    end

    test "raises an error when Gemini is unavailable" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        ).to_return(
            status: 503,
            body: '{"error":{"message":"Service unavailable"}}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(RuntimeError) do
            categorizer.call
        end

        assert_equal "AI request failed with HTTP status 503.", error.message
    end
end
