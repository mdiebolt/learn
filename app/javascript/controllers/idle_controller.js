import { Controller } from "@hotwired/stimulus"

// Marks its element as "idle" (toggling the `idle` CSS class) when the
// pointer has been still for `delayMsValue` wall-clock milliseconds, and
// removes the mark on any movement. Bind a `mousemove@window->idle#bump`
// action so a moving cursor anywhere on the page resets the timer.
export default class extends Controller {
  static values = {
    delayMs: { type: Number, default: 2000 }
  }

  connect() {
    this.bump()
  }

  disconnect() {
    this.clear()
    this.element.classList.remove("idle")
  }

  bump() {
    this.element.classList.remove("idle")
    this.clear()
    this.timeoutId = setTimeout(() => this.element.classList.add("idle"), this.delayMsValue)
  }

  clear() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }
}
