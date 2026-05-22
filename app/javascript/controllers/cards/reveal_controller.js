import { Controller } from "@hotwired/stimulus"

// Swaps the card's action row for its answer section, whether the reader
// graded the interaction or chose to skip straight to the answer.
export default class extends Controller {
  static targets = ["answer", "controls"]

  show() {
    this.answerTarget.hidden = false
    this.controlsTarget.hidden = true
  }
}
