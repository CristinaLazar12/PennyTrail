require "net/http"
require "json"

class ExpenseCategorizer
  class Error < StandardError
  end

  def initialize(description:, amount:)
    @description = description
    @amount = amount
  end

  def prompt
    "Choose one category for this expense. " \
      "Description: #{@description}. " \
      "Amount: #{@amount} RON. " \
      "Allowed categories: #{Expense::CATEGORIES.join(', ')}. " \
      "Return only the category name, without explanations or a prefix."
  end

  def request_body
    {
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ]
    }.to_json
  end

  def call
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"

    api_key = ENV["GEMINI_API_KEY"]

    if api_key.blank?
      raise Error, "AI service is not configured."
    end

    request["x-goog-api-key"] = api_key
    request.body = request_body

    response = nil

    # Retry once after HTTP 503 to handle temporary service unavailability.
    2.times do |attempt|
      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30
      ) do |http|
        http.request(request)
      end

      break unless response.code == "503" && attempt == 0

      sleep 1
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "AI request failed with HTTP status #{response.code}."
    end

    data = JSON.parse(response.body)

    unless data.is_a?(Hash)
      raise Error, "AI service returned an invalid response structure.", cause: nil
    end

    begin
      text = data.dig("candidates", 0, "content", "parts", 0, "text")
    rescue TypeError
      raise Error, "AI service returned an invalid response structure.", cause: nil
    end

    unless text.is_a?(String) && text.strip.present?
      raise Error, "AI service returned no category.", cause: nil
    end

    category = text.strip

    unless Expense::CATEGORIES.include?(category)
      raise Error, "AI returned an unsupported category.", cause: nil
    end

    category
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "AI service timed out. Please try again.", cause: nil
  rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET
    raise Error, "Could not connect to AI service. Please try again.", cause: nil
  rescue JSON::ParserError
    # Avoid attaching parser errors that may contain response data.
    raise Error, "AI service returned invalid JSON.", cause: nil
  end
end
