import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "before", "focal", "after"]
  static values = {
    words: Array,
    startMs: Number,
    endMs: Number
  }

  connect() {
    this.lastIndex = -1
    this.naturalWpm = this.computeNaturalWpm()
    this.tick = this.tick.bind(this)
    this.rafId = null
  }

  disconnect() {
    this.stopTicking()
  }

  onLoadedMetadata() {
    if (this.audioTarget.currentTime < this.startMsValue / 1000) {
      this.audioTarget.currentTime = this.startMsValue / 1000
    }
    this.updateWord()
  }

  onPlay() {
    this.startTicking()
  }

  onPause() {
    this.stopTicking()
    this.updateWord()
  }

  onSeeked() {
    this.updateWord()
  }

  onWpmChange(event) {
    const wpm = Number(event.target.value)
    // Browsers typically support playbackRate in [0.25, 4.0].
    const rate = Math.min(4, Math.max(0.25, wpm / this.naturalWpm))
    this.audioTarget.playbackRate = rate
  }

  computeNaturalWpm() {
    const minutes = (this.endMsValue - this.startMsValue) / 60000
    if (minutes <= 0) return 0
    return this.wordsValue.length / minutes
  }

  startTicking() {
    if (this.rafId === null) {
      this.rafId = requestAnimationFrame(this.tick)
    }
  }

  stopTicking() {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }

  tick() {
    this.updateWord()
    this.rafId = requestAnimationFrame(this.tick)
  }

  updateWord() {
    const timeMs = this.audioTarget.currentTime * 1000
    const index = this.findWordIndex(timeMs)

    if (index !== this.lastIndex) {
      this.lastIndex = index
      this.render(this.wordsValue[index])
    }
  }

  // Binary search for the last word whose `start` is <= timeMs.
  findWordIndex(timeMs) {
    const words = this.wordsValue
    if (words.length === 0 || timeMs < words[0].start) return -1

    let lo = 0
    let hi = words.length - 1
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1
      if (words[mid].start <= timeMs) {
        lo = mid
      } else {
        hi = mid - 1
      }
    }
    return lo
  }

  render(word) {
    if (!word) {
      this.beforeTarget.textContent = ""
      this.focalTarget.textContent = ""
      this.afterTarget.textContent = ""
      return
    }

    const { text, orp } = word
    const safeOrp = Math.min(orp || 0, Math.max(text.length - 1, 0))

    this.beforeTarget.textContent = text.slice(0, safeOrp)
    this.focalTarget.textContent = text[safeOrp] || ""
    this.afterTarget.textContent = text.slice(safeOrp + 1)
  }
}
