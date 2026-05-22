import { Controller } from "@hotwired/stimulus"

// Grades typed-in cloze blanks. Matching is forgiving: extra whitespace,
// capitalization, and minor misspellings still count as correct.
export default class extends Controller {
  static targets = ["blank"]
  static classes = ["correct", "incorrect"]

  check() {
    if (this.checked) return
    this.checked = true

    this.blankTargets.forEach((blank) => {
      blank.readOnly = true
      const correct = this.matches(blank.value, blank.dataset.answer)
      blank.classList.add(...(correct ? this.correctClasses : this.incorrectClasses))
    })

    this.dispatch("graded", { prefix: "card" })
  }

  matches(input, answer) {
    const typed = this.normalize(input)
    const expected = this.normalize(answer)
    if (!typed) return false
    if (typed === expected) return true
    return this.distance(typed, expected) <= this.tolerance(expected)
  }

  normalize(value) {
    return value.trim().toLowerCase().replace(/\s+/g, " ")
  }

  tolerance(answer) {
    return answer.length <= 4 ? 1 : 2
  }

  distance(a, b) {
    const row = Array.from({ length: b.length + 1 }, (_, j) => j)
    for (let i = 1; i <= a.length; i++) {
      let previous = row[0]
      row[0] = i
      for (let j = 1; j <= b.length; j++) {
        const cost = a[i - 1] === b[j - 1] ? 0 : 1
        const next = Math.min(row[j] + 1, row[j - 1] + 1, previous + cost)
        previous = row[j]
        row[j] = next
      }
    }
    return row[b.length]
  }
}
