require "net/http"
require "json"

class ExpenseCategorizer
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
            contents: [ #lista mesajelor trimise
                {
                    parts: [ #partile unui mesaj; noi trimitem o singura parte, text
                        { text: prompt } #apeleaza metoda prompt si pune textul rezultat aici
                    ]
                }
            ]
        }.to_json #transforma hasul Ruby intr-un text JSON, potrivit pt trimitere
    end

    def call
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent") #adresa API catre care vom trimite mesajul
        request = Net::HTTP::Post.new(uri) #pregateste o cerere POST
        request["Content-Type"] = "application/json" #anunta ca trimitem JSON
        request["x-goog-api-key"] = ENV.fetch("GEMINI_API_KEY") #x-goog-api-key pune cheia in antetul cererii. ENV.fetch o citește din variabila setată în terminal; nu scriem cheia în fișier.
        request.body = request_body #pune JSON-ul construit de mine în corpul cererii.

        response = Net::HTTP.start( #trimitem cererea
            uri.hostname, #identifică serverul și portul la care ne conectăm
            uri.port, #portul
            use_ssl: true, #folosește o conexiune HTTPS criptată.
            open_timeout: 10, #așteaptă cel mult 10 secunde pentru conectare
            read_timeout: 30 #limitează așteptarea la citirea răspunsului.
        ) do |http|
            http.request(request) #trimite efectiv cererea pregătită.
        end

        #tratăm cazul în care Gemini răspunde cu o eroare
        unless response.is_a?(Net::HTTPSuccess) #verifică dacă răspunsul HTTP indică succes — un cod din intervalul 200–299
            raise "AI request failed with HTTP status #{response.code}." #daca nu, raise opreste metoda si semnaleaza o eroare
        end

        data = JSON.parse(response.body) #JSON.parse transformă textul JSON într-un hash Ruby
        category = data["candidates"][0]["content"]["parts"][0]["text"].strip #category = ... păstrează textul extras într-o variabilă. Navigăm prin acel hash: primul răspuns din candidates → content → prima parte din parts → text. [0] înseamnă primul element al unei liste.strip elimină spațiile și liniile noi de la început și sfârșit. De exemplu, "Dining Out\n" devine "Dining Out"

        unless Expense::CATEGORIES.include?(category) #daca lista CATEGORIES nu contine exact acea categorie
            raise "AI returned an unsupported category." #semnaleaza o eroare
        end

        category #valoarea returnată de metodă atunci când verificarea trece
    end
end
