require "test_helper"

class ExpenseCategorizerTest < ActiveSupport::TestCase
    setup do
        @original_api_key = ENV["GEMINI_API_KEY"]
        ENV["GEMINI_API_KEY"] = "test-key"
    end

    teardown do
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: fake_response.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end
    end

    test "raises an error when Gemini is unavailable" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 503,
            body: '{"error":{"message":"Service unavailable"}}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI request failed with HTTP status 503.", error.message
    end

    test "raises an error when the request times out" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_raise(Net::ReadTimeout)

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service timed out. Please try again.", error.message
    end

    test "raises an error when the connection times out" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_raise(Net::OpenTimeout)

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service timed out. Please try again.", error.message
    end

    test "raises an error when the connection is refused" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_raise(Errno::ECONNREFUSED)

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "Could not connect to AI service. Please try again.", error.message
    end

    test "raises an error when the response is not valid JSON" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: "not valid JSON",
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service returned invalid JSON.", error.message
        assert_nil error.cause
    end

    test "raises an error when the category is missing" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: '{"candidates":[]}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service returned no category.", error.message
    end

    test "raises an error when the category is blank" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: {
                candidates: [
                    {
                        content: {
                            parts: [
                                { text: "   " }
                            ]
                        }
                    }
                ]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service returned no category.", error.message
    end

    test "raises an error when authentication fails" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 401,
            body: '{"error":{"message":"Unauthenticated"}}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI request failed with HTTP status 401.", error.message
    end

    test "raises an error when the rate limit is reached" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 429,
            body: '{"error":{"message":"Resource exhausted"}}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI request failed with HTTP status 429.", error.message
    end

    test "raises an error when the response structure is invalid" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
            status: 200,
            body: '{"candidates":"unexpected"}',
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service returned an invalid response structure.", error.message
    end

    test "raises an error when the server cannot be resolved" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_raise(SocketError)

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "Could not connect to AI service. Please try again.", error.message
    end

    test "raises an error when the connection is reset" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_raise(Errno::ECONNRESET)

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "Could not connect to AI service. Please try again.", error.message
    end

    test "raises an error when the API key is missing" do
        ENV.delete("GEMINI_API_KEY")

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI service is not configured.", error.message
    end

    test "retries once when Gemini returns 503" do
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

        request_stub = stub_request(
        :post,
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"
        ).to_return(
        status: 503,
        body: '{"error":{"message":"Unavailable"}}'
        ).then.to_return(
        status: 200,
        body: fake_response.to_json,
        headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
        description: "Dinner at Restaurant",
        amount: "120.50"
        )

        assert_equal "Dining Out", categorizer.call
        assert_requested request_stub, times: 2
    end
end
