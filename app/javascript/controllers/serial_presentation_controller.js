import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["beforeFocal", "focalCharacter", "afterFocal"]

  connect() {
    this.onWordChange = this.onWordChange.bind(this)
    this.element.addEventListener("audio-sync:wordChange", this.onWordChange)
  }

  disconnect() {
    this.element.removeEventListener("audio-sync:wordChange", this.onWordChange)
  }

  onWordChange(event) {
    const { word, optimal_recognition_point } = event.detail
    this.renderWord(word, optimal_recognition_point)
  }

  renderWord(word, optimalRecognitionPoint) {
    if (!word) return

    const safeIndex = Math.min(optimalRecognitionPoint || 0, word.length - 1)

    this.beforeFocalTarget.textContent = word.slice(0, safeIndex)
    this.focalCharacterTarget.textContent = word[safeIndex] || ""
    this.afterFocalTarget.textContent = word.slice(safeIndex + 1)
  }
}
