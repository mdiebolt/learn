import { Controller } from "@hotwired/stimulus"

// Bare control of the chapter's audio segment plus the shared playback UI
// (seek scrubber, current/total time labels, WPM-to-rate select). Owns the
// `<audio>` element and the chapter bounds; other controllers listen to
// the `playback:*` events we dispatch and read `audio.currentTime` from
// their own target on the same element.
export default class extends Controller {
  static targets = ["audio", "seek", "currentTime", "duration", "wpm"]
  static values = {
    startMs: Number,
    endMs: Number,
    initialMs: Number,
    naturalWpm: Number
  }

  connect() {
    this.tick = this.tick.bind(this)
    this.rafId = null
    this.chapterEnded = false
    this.durationTarget.textContent = this.formatTime(this.endMsValue - this.startMsValue)
  }

  disconnect() {
    this.stopTicking()
    this.setPlaybackActive(false)
  }

  // ---- User-driven control -------------------------------------------

  // Click anywhere on the chapter wrapper toggles playback. Real controls
  // (links, buttons, inputs, the wpm select, anything tagged
  // `data-playback-no-toggle`) opt out via `closest`, so clicking them
  // doesn't double-fire as toggle.
  togglePlayFromClick(event) {
    if (event.target.closest("a, button, input, select, label, [data-playback-no-toggle]")) return
    this.togglePlay()
  }

  // Space toggles only when focus is on the body — typing in an input,
  // hitting space on a button, or opening a select still does the native
  // thing.
  togglePlayFromKey(event) {
    if (document.activeElement && document.activeElement !== document.body) return
    event.preventDefault()
    this.togglePlay()
  }

  togglePlay() {
    if (this.audioTarget.paused) {
      this.play()
    } else {
      this.pause()
    }
  }

  play() {
    this.audioTarget.play().catch((error) => {
      console.warn("Audio play() rejected:", error)
    })
  }

  onError() {
    const error = this.audioTarget.error
    console.warn("Audio element error:", error && error.code, error && error.message)
  }

  pause() {
    this.audioTarget.pause()
  }

  seek(event) {
    const fraction = Number(event.target.value) / 1000
    const chapterMs = fraction * (this.endMsValue - this.startMsValue)
    this.audioTarget.currentTime = (this.startMsValue + chapterMs) / 1000
  }

  setRate(event) {
    this.audioTarget.playbackRate = this.computeRate(Number(event.target.value))
  }

  // playbackRate is browser-clamped to [0.25, 4.0].
  computeRate(wpm) {
    if (!this.naturalWpmValue) return 1
    return Math.min(4, Math.max(0.25, wpm / this.naturalWpmValue))
  }

  // ---- Audio-element event handlers ----------------------------------
  // Bound via data-action on the <audio> element. We do small bookkeeping
  // (start/stop the scrubber rAF, apply initial seek, detect end of
  // chapter) and re-dispatch as bubbling `playback:*` events so other
  // controllers on the wrapper can react.

  onPlay() {
    this.setPlaybackActive(true)
    this.startTicking()
    this.dispatch("play", { prefix: "playback" })
  }

  onPause() {
    this.setPlaybackActive(false)
    this.stopTicking()
    this.updateUI()
    this.dispatch("pause", { prefix: "playback" })
  }

  // Mirrored on the wrapper (for in-frame styles like cursor: none) and
  // on `<body>` (for layout-level styles like the logo fade, which
  // lives outside the wrapper).
  setPlaybackActive(active) {
    this.element.classList.toggle("playback-active", active)
    document.body.classList.toggle("playback-active", active)
  }

  onSeeked() {
    this.updateUI()
    this.dispatch("seeked", { prefix: "playback" })
  }

  onLoadedMetadata() {
    const initialMs = this.initialMsValue
    if (initialMs > this.startMsValue && initialMs < this.endMsValue) {
      this.audioTarget.currentTime = initialMs / 1000
    } else if (this.audioTarget.currentTime < this.startMsValue / 1000) {
      this.audioTarget.currentTime = this.startMsValue / 1000
    }
    if (this.hasWpmTarget) {
      this.audioTarget.playbackRate = this.computeRate(Number(this.wpmTarget.value))
    }
    this.updateUI()
    this.dispatch("loadedmetadata", { prefix: "playback" })
  }

  // Crossing the chapter's end_time_ms while playing fires `chapterend`
  // exactly once per controller lifetime. We pause and snap currentTime
  // to the boundary before dispatching so listeners (progress save,
  // autoplay advance) see a consistent terminal state.
  onTimeUpdate() {
    if (this.chapterEnded) return
    if (this.audioTarget.currentTime * 1000 < this.endMsValue) return
    this.chapterEnded = true
    this.stopTicking()
    this.audioTarget.currentTime = this.endMsValue / 1000
    if (!this.audioTarget.paused) this.audioTarget.pause()
    this.dispatch("chapterend", { prefix: "playback" })
  }

  // ---- Scrubber + time-label loop ------------------------------------

  startTicking() {
    if (this.rafId === null) this.rafId = requestAnimationFrame(this.tick)
  }

  stopTicking() {
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId)
      this.rafId = null
    }
  }

  tick() {
    this.updateUI()
    this.rafId = requestAnimationFrame(this.tick)
  }

  updateUI() {
    const elapsedMs = this.audioTarget.currentTime * 1000 - this.startMsValue
    const totalMs = this.endMsValue - this.startMsValue
    const fraction = totalMs > 0 ? Math.max(0, Math.min(1, elapsedMs / totalMs)) : 0
    if (this.hasSeekTarget) this.seekTarget.value = String(fraction * 1000)
    if (this.hasCurrentTimeTarget) this.currentTimeTarget.textContent = this.formatTime(Math.max(0, elapsedMs))
  }

  formatTime(ms) {
    const totalSec = Math.max(0, Math.floor(ms / 1000))
    const min = Math.floor(totalSec / 60)
    const sec = totalSec % 60
    return `${min}:${String(sec).padStart(2, "0")}`
  }
}
