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
        fake_response = { # pregătim un răspuns cu aceeași structură ca răspunsul Gemini.
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

        stub_request( # îi spunem lui WebMock: „Când codul face POST la această adresă, returnează răspunsul nostru.”
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        ).to_return(
            status: 200, # simulăm o cerere reușită.
            body: fake_response.to_json,
            headers: { "Content-Type" => "application/json" }
        )

        categorizer = ExpenseCategorizer.new(
            description: "Dinner at Restaurant",
            amount: "120.50"
        )

        assert_equal "Dining Out", categorizer.call # categorizer.call — execută codul nostru, dar WebMock înlocuiește comunicarea cu serverul.
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

        assert_raises(ExpenseCategorizer::Error) do # assert_raises verifică dacă acel cod semnalează o eroare. Aici ne așteptăm la eroarea produsă de raise "AI returned an unsupported category."
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

        error = assert_raises(ExpenseCategorizer::Error) do
            categorizer.call
        end

        assert_equal "AI request failed with HTTP status 503.", error.message
    end

    test "raises an error when the request times out" do
        stub_request(
            :post,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
        ).to_raise(Net::ReadTimeout) # to_raise simulează o eroare în timpul cererii, fără să contacteze Gemini sau să aștepte.

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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
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
end
