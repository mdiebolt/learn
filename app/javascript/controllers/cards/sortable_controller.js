import { Controller } from "@hotwired/stimulus"

// Drag-to-reorder list with a deferred check: items carry their canonical
// position and `check` reveals correctness once the reader confirms. Powers
// both ordering cards and the draggable column of matching cards.
export default class extends Controller {
  static targets = ["item", "list"]
  static classes = ["dragging", "grab", "locked", "correct", "incorrect"]

  dragStart(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", "")
    requestAnimationFrame(() => this.dragged.classList.add(...this.draggingClasses))
  }

  dragOver(event) {
    if (!this.dragged) return
    event.preventDefault()

    const after = this.itemAfter(event.clientY)
    if (after === this.dragged) return
    if (after) {
      this.listTarget.insertBefore(this.dragged, after)
    } else {
      this.listTarget.appendChild(this.dragged)
    }
  }

  drop(event) {
    event.preventDefault()
  }

  dragEnd() {
    if (this.dragged) this.dragged.classList.remove(...this.draggingClasses)
    this.dragged = null
  }

  check() {
    if (this.checked) return
    this.checked = true

    this.itemTargets.forEach((item, index) => {
      item.draggable = false
      item.classList.remove(...this.grabClasses)
      item.classList.add(...this.lockedClasses)
      const correct = Number(item.dataset.position) === index
      item.classList.add(...(correct ? this.correctClasses : this.incorrectClasses))
    })

    this.dispatch("graded", { prefix: "card" })
  }

  itemAfter(y) {
    return this.itemTargets
      .filter((item) => item !== this.dragged)
      .find((item) => {
        const box = item.getBoundingClientRect()
        return y < box.top + box.height / 2
      })
  }
}
