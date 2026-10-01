import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suggestion", "token"]

  invalidate() {
    if (this.hasSuggestionTarget) {
      this.suggestionTarget.hidden = true
    }

    if (this.hasTokenTarget) {
      this.tokenTarget.value = ""
    }
  }
}
