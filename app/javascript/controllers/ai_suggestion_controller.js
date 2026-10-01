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
