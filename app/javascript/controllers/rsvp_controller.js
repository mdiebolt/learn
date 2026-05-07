import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "audio", "before", "focal", "after",
    "playButton", "currentTime", "duration", "seek"
  ]
  static values = {
    words: Array,
    startMs: Number,
    endMs: Number,
    nextChapterUrl: String,
    autoplay: Boolean
  }

  connect() {
    this.lastIndex = -1
    this.naturalWpm = this.computeNaturalWpm()
    this.tick = this.tick.bind(this)
    this.rafId = null
    this.advanced = false
    this.durationTarget.textContent = this.formatTime(this.endMsValue - this.startMsValue)
  }

  disconnect() {
    this.stopTicking()
  }

  onLoadedMetadata() {
    if (this.audioTarget.currentTime < this.startMsValue / 1000) {
      this.audioTarget.currentTime = this.startMsValue / 1000
    }
    this.updateProgress()
    this.updateWord()
    if (this.autoplayValue) {
      this.audioTarget.play().catch(() => {})
    }
  }

  togglePlay() {
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  onPlay() {
    this.playButtonTarget.textContent = "⏸"
    this.playButtonTarget.setAttribute("aria-label", "Pause")
    this.startTicking()
  }

  onPause() {
    this.playButtonTarget.textContent = "▶"
    this.playButtonTarget.setAttribute("aria-label", "Play")
    this.stopTicking()
    this.updateWord()
    this.updateProgress()
  }

  onSeek(event) {
    const fraction = Number(event.target.value) / 1000
    const chapterMs = fraction * (this.endMsValue - this.startMsValue)
    this.audioTarget.currentTime = (this.startMsValue + chapterMs) / 1000
  }

  onSeeked() {
    this.updateProgress()
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
    this.updateProgress()
    this.rafId = requestAnimationFrame(this.tick)
  }

  updateWord() {
    const timeMs = this.audioTarget.currentTime * 1000

    if (timeMs >= this.endMsValue) {
      this.handleChapterEnd()
      return
    }

    const index = this.findWordIndex(timeMs)

    if (index !== this.lastIndex) {
      this.lastIndex = index
      this.render(this.wordsValue[index])
    }
  }

  updateProgress() {
    const elapsedMs = this.audioTarget.currentTime * 1000 - this.startMsValue
    const totalMs = this.endMsValue - this.startMsValue
    const fraction = totalMs > 0 ? Math.max(0, Math.min(1, elapsedMs / totalMs)) : 0
    this.seekTarget.value = String(fraction * 1000)
    this.currentTimeTarget.textContent = this.formatTime(Math.max(0, elapsedMs))
  }

  handleChapterEnd() {
    if (this.advanced) return
    this.advanced = true
    this.stopTicking()
    this.audioTarget.currentTime = this.endMsValue / 1000
    if (!this.audioTarget.paused) this.audioTarget.pause()

    if (this.nextChapterUrlValue) {
      const url = new URL(this.nextChapterUrlValue, window.location.origin)
      url.searchParams.set("autoplay", "1")
      window.Turbo.visit(url.toString())
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

  formatTime(ms) {
    const totalSec = Math.max(0, Math.floor(ms / 1000))
    const min = Math.floor(totalSec / 60)
    const sec = totalSec % 60
    return `${min}:${String(sec).padStart(2, "0")}`
  }
}
