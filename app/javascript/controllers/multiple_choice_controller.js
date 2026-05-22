import { Controller } from "@hotwired/stimulus"

// Lets the reader pick an option, then grades that choice on submit (or when
// the answer is revealed). Correctness stays hidden until then.
export default class extends Controller {
  static targets = ["option"]
  static values = { correctIndex: Number }
  static classes = ["hover", "selected", "locked", "correct", "incorrect"]

  choose(event) {
    if (this.graded) return
    this.chosen = Number(event.params.index)
    this.optionTargets.forEach((option, index) => {
      option.classList.toggle(this.selectedClass, index === this.chosen)
    })
  }

  check() {
    if (this.graded) return
    this.graded = true

    this.optionTargets.forEach((option, index) => {
      option.classList.remove(...this.hoverClasses, ...this.selectedClasses)
      option.classList.add(...this.lockedClasses)
      if (index === this.correctIndexValue) {
        option.classList.add(...this.correctClasses)
      } else if (index === this.chosen) {
        option.classList.add(...this.incorrectClasses)
      }
    })

    this.dispatch("graded", { prefix: "card" })
  }
}
