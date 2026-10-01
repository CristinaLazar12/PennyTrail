# Learning notes

Personal notes from building PennyTrail with AI-assisted guidance.

## Expense categorization service

```ruby


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
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent") # adresa API către care vom trimite mesajul
        request = Net::HTTP::Post.new(uri) # pregateste o cerere POST
        request["Content-Type"] = "application/json" # anunta ca trimitem JSON

        api_key = ENV["GEMINI_API_KEY"]

            if api_key.blank?
                raise Error, "AI service is not configured."
            end

            request["x-goog-api-key"] = api_key

        request.body = request_body # pune JSON-ul construit de mine în corpul cererii.

        response = nil

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
```


## Stimulus: invalidating AI suggestions

```javascript
import { Controller } from "@hotwired/stimulus"
// Importăm controllerul oferit de Stimulus; Vreau să folosesc clasa Controller din biblioteca Stimulus

// Connects to data-controller="ai-suggestion"
export default class extends Controller {
// definim controllerul nostru. extends Controller înseamnă că moștenește funcționalitatea controllerului Stimulus
// export default permite ca această clasă să fie importată și înregistrată de aplicație  
static targets = ["suggestion", "token"]
// Un target este un element HTML pe care îl marcăm ca să îl găsim ușor din controller.
// suggestion: zona care afișează „AI suggestion: Dining Out”.
// token: câmpul ascuns care păstrează dovada semnată a sugestiei.

  invalidate() { // metoda JavaScript
    // Am ales numele invalidate pentru că metoda face sugestia veche inutilizabilă în formular.
    if (this.hasSuggestionTarget) {
      // Verificăm dacă există o sugestie afișată
      // this se referă la instanța acestui controller.
      // Stimulus generează automat proprietatea hasSuggestionTarget, deoarece am declarat targetul "suggestion"
      // Verificarea ne permite să folosim formularul și când nu avem nicio sugestie.
      this.suggestionTarget.hidden = true
      // Ascundem sugestia
      // Asta nu șterge nimic din baza de date. Ascunde doar mesajul din pagina curentă.
    }

    if (this.hasTokenTarget) {
      // Verificăm dacă există câmpul cu tokenul
      this.tokenTarget.value = ""
      // Golim tokenul; value este valoarea câmpului, iar "" înseamnă text gol.
      // Astfel, la salvare, formularul nu mai trimite tokenul sugestiei vechi cu o valoare utilizabilă.
    }
  } 
}

// Nu golim categoria aleasă de utilizator. El poate păstra selecția manuală sau o poate schimba.
// Intreg comportamentul va fi:
// 1. Introduci „Dinner at restaurant”, suma 120.
// 2. Primești sugestia Dining Out și tokenul asociat.
// 3. Modifici descrierea în „Bus ticket”.
// 4. Browserul apelează invalidate().
// 5. Mesajul cu sugestia dispare, iar tokenul este golit.
// 6. Poți cere o sugestie nouă sau salva cu o categorie aleasă manual.


```
```test

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest" # activează integrarea cu testele Minitest.

WebMock.disable_net_connect!(allow_localhost: true)

# disable_net_connect! blochează cererile reale către internet în teste. Astfel, o cerere către Gemini fără răspuns simulat va produce o eroare locală.
# allow_localhost: true permite conexiunile locale, necesare pentru testele care pornesc aplicația pe calculatorul tău.

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
```
