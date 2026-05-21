import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["answer", "trigger"]

  show() {
    this.answerTarget.hidden = false
    this.triggerTarget.hidden = true
  }
}
