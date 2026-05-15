import { Controller } from "@hotwired/stimulus"

// Small head-start (wall-clock ms) so the eye sees the next word a beat
// before it's audible. Anything beyond ~50ms starts to feel ahead; below
// ~15ms the cut feels late. 30ms is the sweet spot once output latency
// is being compensated for separately.
const ARTISTIC_LEAD_WALL_MS = 30

// Word display only. Reads `audio.currentTime` each frame, picks the
// matching word from `wordsValue`, and renders it centered on the focal
// column. Subscribes to `playback:*` events to start/stop its rAF loop,
// and exposes a sync-offset slider that the user can nudge to dial in
// audio/word alignment for their output device.
export default class extends Controller {
  static targets = ["audio", "word", "audioOffset", "audioOffsetReadout"]
  static values = {
    words: Array,
    audioOffsetMs: Number
  }

  connect() {
    this.lastIndex = -1
    this.tick = this.tick.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.rafId = null
    this.audioCtx = this.createAudioCtx()
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    this.stopTicking()
    if (this.audioCtx) {
      this.audioCtx.close().catch(() => {})
      this.audioCtx = null
    }
    window.removeEventListener("resize", this.handleResize)
  }

  // ---- Playback event handlers ---------------------------------------

  onPlay() {
    // The click/space that triggered playback still counts as a recent
    // user gesture here, which is what `audioCtx.resume()` needs.
    if (this.audioCtx && this.audioCtx.state === "suspended") {
      this.audioCtx.resume().catch(() => {})
    }
    this.startTicking()
  }

  onPause() {
    this.stopTicking()
    this.updateWord()
  }

  onSeeked() {
    this.updateWord()
  }

  onLoadedMetadata() {
    this.updateWord()
  }

  onChapterEnd() {
    this.stopTicking()
  }

  // ---- Sync-offset slider --------------------------------------------

  setAudioOffset(event) {
    this.audioOffsetMsValue = Number(event.target.value)
    if (this.hasAudioOffsetReadoutTarget) {
      this.audioOffsetReadoutTarget.textContent = this.formatOffset(this.audioOffsetMsValue)
    }
    this.updateWord()
  }

  // ---- Word display loop ---------------------------------------------

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
    this.updateWord()
    this.rafId = requestAnimationFrame(this.tick)
  }

  updateWord() {
    const timeMs = this.audioTarget.currentTime * 1000
    const index = this.findWordIndex(timeMs + this.leadMediaMs())
    if (index !== this.lastIndex) {
      this.lastIndex = index
      this.render(this.wordsValue[index])
    }
  }

  // Re-position the current word when the frame's width changes, since
  // `style.left` is written in pixels relative to the frame.
  handleResize() {
    const word = this.lastIndex >= 0 ? this.wordsValue[this.lastIndex] : null
    if (word) this.render(word)
  }

  // ---- Latency probe and lead math -----------------------------------

  // A latency-probe AudioContext. We do NOT route the `<audio>` element
  // through it — the native playback path is untouched. The context
  // exists only so `baseLatency + outputLatency` can tell us how far
  // behind `audio.currentTime` the user actually hears the audio
  // (typically ~150ms on Bluetooth/AirPods, ~30ms on wired/built-in).
  // Starts suspended in most browsers; resumed in `onPlay` since some
  // implementations only report useful `outputLatency` values once the
  // context is running.
  createAudioCtx() {
    const Ctx = window.AudioContext || window.webkitAudioContext
    if (!Ctx) return null
    try {
      return new Ctx()
    } catch (_) {
      return null
    }
  }

  // Wall-clock ms between when a sample is scheduled (advancing
  // `audio.currentTime`) and when it actually reaches the ear. Reactive
  // to output-device changes in Chrome/Firefox. Returns 0 in browsers
  // without an AudioContext.
  latencyWallMs() {
    if (!this.audioCtx) return 0
    const base = this.audioCtx.baseLatency || 0
    const output = this.audioCtx.outputLatency || 0
    return (base + output) * 1000
  }

  // Media-time offset to add to `currentTime` when picking the word that
  // should be displayed now. Three wall-clock components: artistic lead
  // (eye gets a head-start), the user's sync nudge, and the device's
  // output latency (subtracted, since heard audio trails `currentTime`).
  // Rescaled by `playbackRate` so the *perceived* lead is constant
  // across WPM choices — at 2× rate, 30ms of wall-clock lead is 60ms of
  // media time.
  leadMediaMs() {
    const rate = this.audioTarget.playbackRate || 1
    return (ARTISTIC_LEAD_WALL_MS + this.audioOffsetMsValue - this.latencyWallMs()) * rate
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

  formatOffset(ms) {
    return `${ms >= 0 ? "+" : ""}${ms}ms`
  }
}
