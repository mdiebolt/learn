import { Controller } from "@hotwired/stimulus"

const PROGRESS_SAVE_INTERVAL_MS = 5000
const WORD_LEAD_MS = 75

export default class extends Controller {
  static targets = [
    "audio", "word",
    "currentTime", "duration", "seek", "wpm"
  ]
  static values = {
    words: Array,
    startMs: Number,
    endMs: Number,
    nextChapterUrl: String,
    autoplay: Boolean,
    preferencesUrl: String,
    progressUrl: String,
    initialProgressMs: Number
  }

  connect() {
    this.lastIndex = -1
    this.naturalWpm = this.computeNaturalWpm()
    this.tick = this.tick.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.rafId = null
    this.advanced = false
    this.lastSavedProgressMs = -1
    this.progressSaveInterval = null
    this.durationTarget.textContent = this.formatTime(this.endMsValue - this.startMsValue)
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    this.stopTicking()
    this.stopProgressSaving()
    this.saveProgress()
    window.removeEventListener("resize", this.handleResize)
  }

  // Re-position the current word when the frame's width changes, since
  // `style.left` is written in pixels relative to the frame.
  handleResize() {
    const word = this.lastIndex >= 0 ? this.wordsValue[this.lastIndex] : null
    if (word) this.render(word)
  }

  onLoadedMetadata() {
    const progressMs = this.initialProgressMsValue
    if (progressMs > this.startMsValue && progressMs < this.endMsValue) {
      this.audioTarget.currentTime = progressMs / 1000
    } else if (this.audioTarget.currentTime < this.startMsValue / 1000) {
      this.audioTarget.currentTime = this.startMsValue / 1000
    }
    if (this.hasWpmTarget) {
      this.audioTarget.playbackRate = this.computeRate(Number(this.wpmTarget.value))
    }
    this.updateProgress()
    this.updateWord()
    if (this.autoplayValue) {
      this.audioTarget.play().catch(() => {})
    }
  }

  // Bound to the page-level wrapper so clicking anywhere toggles playback.
  // Real controls (links, buttons, scrubber, select, labels) opt out via
  // `closest`, so clicks on them don't double-fire as toggle.
  togglePlay(event) {
    if (event && event.target.closest("a, button, input, select, label, [data-rsvp-no-toggle]")) return
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  // Space toggles play/pause; F enters/exits fullscreen.
  // Only act when nothing specific is focused — letting native key behavior
  // (typing, opening a select, activating a focused button) win otherwise.
  onKeydown(event) {
    const active = document.activeElement
    if (active && active !== document.body) return

    if (event.code === "Space") {
      event.preventDefault()
      this.togglePlay()
    } else if (event.key === "f" || event.key === "F") {
      event.preventDefault()
      this.toggleFullscreen()
    }
  }

  // Fullscreens the document so the immersive view persists across
  // Turbo Drive navigations to the next chapter.
  toggleFullscreen() {
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      document.documentElement.requestFullscreen().catch(() => {})
    }
  }

  onPlay() {
    this.startTicking()
    this.startProgressSaving()
  }

  onPause() {
    this.stopTicking()
    this.stopProgressSaving()
    this.updateWord()
    this.updateProgress()
    this.saveProgress()
  }

  onSeek(event) {
    const fraction = Number(event.target.value) / 1000
    const chapterMs = fraction * (this.endMsValue - this.startMsValue)
    this.audioTarget.currentTime = (this.startMsValue + chapterMs) / 1000
  }

  onSeeked() {
    this.updateProgress()
    this.updateWord()
    this.saveProgress()
  }

  onWpmChange(event) {
    const wpm = Number(event.target.value)
    this.audioTarget.playbackRate = this.computeRate(wpm)
    this.savePreference(wpm)
  }

  // playbackRate is browser-clamped to [0.25, 4.0].
  computeRate(wpm) {
    if (!this.naturalWpm) return 1
    return Math.min(4, Math.max(0.25, wpm / this.naturalWpm))
  }

  savePreference(wpm) {
    if (!this.hasPreferencesUrlValue) return
    this.fetchJson(this.preferencesUrlValue, "PATCH", { wpm })
  }

  startProgressSaving() {
    if (this.progressSaveInterval !== null) return
    this.progressSaveInterval = setInterval(() => this.saveProgress(), PROGRESS_SAVE_INTERVAL_MS)
  }

  stopProgressSaving() {
    if (this.progressSaveInterval !== null) {
      clearInterval(this.progressSaveInterval)
      this.progressSaveInterval = null
    }
  }

  saveProgress(extra = {}) {
    if (!this.hasProgressUrlValue) return
    const progressMs = Math.floor(this.audioTarget.currentTime * 1000)
    const isCompletion = "completed" in extra
    if (progressMs === this.lastSavedProgressMs && !isCompletion) return
    this.lastSavedProgressMs = progressMs
    this.fetchJson(this.progressUrlValue, "PATCH", { progress_ms: progressMs, ...extra })
  }

  fetchJson(url, method, body) {
    const tokenEl = document.querySelector('meta[name="csrf-token"]')
    const headers = { "Content-Type": "application/json", "Accept": "application/json" }
    if (tokenEl) headers["X-CSRF-Token"] = tokenEl.content
    fetch(url, { method, headers, body: JSON.stringify(body) }).catch(() => {})
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

    const index = this.findWordIndex(timeMs + WORD_LEAD_MS)

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
    this.stopProgressSaving()
    this.audioTarget.currentTime = this.endMsValue / 1000
    if (!this.audioTarget.paused) this.audioTarget.pause()

    this.saveProgress({ completed: true })

    if (this.nextChapterUrlValue) {
      const url = new URL(this.nextChapterUrlValue, window.location.origin)
      url.searchParams.set("autoplay", "1")
      window.Turbo.visit(url.toString())
    }
  }

  // Binary search for the last word whose `start` is <= timeMs.
  // When timeMs is before the first word (typical at a fresh chapter load,
  // since chapter.start_time_ms can precede the first word's start), we
  // surface word 0 so the reader sees the upcoming word instead of a blank.
  findWordIndex(timeMs) {
    const words = this.wordsValue
    if (words.length === 0) return -1
    if (timeMs < words[0].start) return 0

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

  // Render the word as a single inline text run with the focal letter
  // wrapped in an inner span (color only). Then translate the whole run
  // so the focal letter's center sits on the frame's 1/3 anchor — the
  // same X as `.rsvp-line`. The word's natural kerning and letter-
  // spacing are never disturbed; only the run as a whole moves.
  render(word) {
    if (!word) {
      this.wordTarget.textContent = ""
      this.wordTarget.style.left = ""
      return
    }

    const { text, orp } = word
    const safeOrp = Math.min(orp || 0, Math.max(text.length - 1, 0))

    this.wordTarget.textContent = ""

    if (safeOrp > 0) {
      this.wordTarget.appendChild(document.createTextNode(text.slice(0, safeOrp)))
    }

    const focalSpan = document.createElement("span")
    focalSpan.className = "rsvp-focal"
    focalSpan.textContent = text[safeOrp] || ""
    this.wordTarget.appendChild(focalSpan)

    if (safeOrp + 1 < text.length) {
      this.wordTarget.appendChild(document.createTextNode(text.slice(safeOrp + 1)))
    }

    const frame = this.wordTarget.parentElement
    if (!frame) return
    const focalCenter = focalSpan.offsetLeft + focalSpan.offsetWidth / 2
    this.wordTarget.style.left = `${frame.offsetWidth / 3 - focalCenter}px`
  }

  formatTime(ms) {
    const totalSec = Math.max(0, Math.floor(ms / 1000))
    const min = Math.floor(totalSec / 60)
    const sec = totalSec % 60
    return `${min}:${String(sec).padStart(2, "0")}`
  }
}
