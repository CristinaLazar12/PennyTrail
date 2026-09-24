require "net/http"
require "json"

class ExpenseCategorizer
    class Error < StandardError # class Error definește un tip de eroare al nostru.;< StandardError înseamnă că moștenește comportamentul unei erori Ruby obișnuite
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
            contents: [ # lista mesajelor trimise
                {
                    parts: [ # partile unui mesaj; noi trimitem o singura parte, text
                        { text: prompt } # apeleaza metoda prompt si pune textul rezultat aici
                    ]
                }
            ]
        }.to_json # transforma hasul Ruby intr-un text JSON, potrivit pt trimitere
    end

    def call
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent") # adresa API catre care vom trimite mesajul
        request = Net::HTTP::Post.new(uri) # pregateste o cerere POST
        request["Content-Type"] = "application/json" # anunta ca trimitem JSON
        request["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY") # x-goog-api-key pune cheia in antetul cererii. ENV.fetch o citește din variabila setată în terminal; nu scriem cheia în fișier.
        request.body = request_body # pune JSON-ul construit de mine în corpul cererii.

        response = Net::HTTP.start( # trimitem cererea
            uri.hostname, # identifică serverul și portul la care ne conectăm
            uri.port, # portul
            use_ssl: true, # folosește o conexiune HTTPS criptată.
            open_timeout: 10, # așteaptă cel mult 10 secunde pentru conectare
            read_timeout: 30 # limitează așteptarea la citirea răspunsului.
        ) do |http|
            http.request(request) # trimite efectiv cererea pregătită.
        end

        # tratăm cazul în care Gemini răspunde cu o eroare
        unless response.is_a?(Net::HTTPSuccess) # verifică dacă răspunsul HTTP indică succes — un cod din intervalul 200–299
            raise Error, "AI request failed with HTTP status #{response.code}." # daca nu, raise opreste metoda si semnaleaza o eroare
        end

        data = JSON.parse(response.body) # JSON.parse transformă textul JSON într-un hash Ruby

        unless data.is_a?(Hash) # verifică dacă răspunsul are la bază un obiect JSON, cum ne așteptăm
            raise Error, "AI service returned an invalid response structure.", cause: nil
        end

        begin
            text = data.dig("candidates", 0, "content", "parts", 0, "text")
        rescue TypeError
            raise Error, "AI service returned an invalid response structure.", cause: nil
        end
        # tratează eroarea doar pentru extragerea cu dig

        unless text.is_a?(String) && text.strip.present?
            # text.is_a?(String) verifică dacă valoarea este text.
            # && înseamnă „și”; verificarea din dreapta se execută doar dacă prima este adevărată.
            # text.strip.present? verifică dacă textul nu este gol după eliminarea spațiilor.
            raise Error, "AI service returned no category.", cause: nil
        end

        category = text.strip

        unless Expense::CATEGORIES.include?(category) # daca lista CATEGORIES nu contine exact acea categorie
            raise Error, "AI returned an unsupported category.", cause: nil # semnaleaza o eroare
        end

        category # valoarea returnată de metodă atunci când verificarea trece
    rescue Net::OpenTimeout, Net::ReadTimeout
        # Net::OpenTimeout — nu am reușit să stabilim conexiunea în timpul permis.
        # Net::ReadTimeout — am așteptat prea mult la citirea răspunsului.
        # rescue — interceptează aceste erori produse în metoda call.
        raise Error, "AI service timed out. Please try again.", cause: nil
    # raise Error — le transformă în tipul nostru comun, ExpenseCategorizer::Error.
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET
        # SocketError — o problemă de rețea, de exemplu găsirea adresei serverului.
        # Errno::ECONNREFUSED — conexiunea a fost refuzată.
        # Errno::ECONNRESET — conexiunea a fost întreruptă brusc.
        raise Error, "Could not connect to AI service. Please try again.", cause: nil
    rescue JSON::ParserError # un răspuns care nu este JSON valid
        raise Error, "AI service returned invalid JSON.", cause: nil
    end
end
