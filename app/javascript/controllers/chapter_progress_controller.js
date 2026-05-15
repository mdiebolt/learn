import { Controller } from "@hotwired/stimulus"

const SAVE_INTERVAL_MS = 5000

// Persists how far the user has gotten into a chapter. Subscribes to the
// playback controller's `playback:*` events and PATCHes the current
// position to its URL value — every 5s during play, on pause/seek, on
// chapter end (with `completed: true`), and beacon-style on page hide.
export default class extends Controller {
  static targets = ["audio"]
  static values = { url: String }

  connect() {
    this.lastSavedMs = -1
    this.intervalId = null
    this.beacon = this.beacon.bind(this)
    window.addEventListener("pagehide", this.beacon)
  }

  disconnect() {
    this.stopInterval()
    this.beacon()
    window.removeEventListener("pagehide", this.beacon)
  }

  onPlay() {
    if (this.intervalId !== null) return
    this.intervalId = setInterval(() => this.save(), SAVE_INTERVAL_MS)
  }

  onPause() {
    this.stopInterval()
    this.save()
  }

  onSeeked() {
    this.save()
  }

  onChapterEnd() {
    this.stopInterval()
    this.save({ completed: true })
  }

  save(extra = {}) {
    if (!this.hasUrlValue) return
    const progressMs = Math.floor(this.audioTarget.currentTime * 1000)
    const isCompletion = "completed" in extra
    if (progressMs === this.lastSavedMs && !isCompletion) return
    this.lastSavedMs = progressMs
    this.fetchJson(this.urlValue, "PATCH", { progress_ms: progressMs, ...extra })
  }

  // Beacon-style save for `pagehide` and `disconnect`. `keepalive: true`
  // lets the request continue past page unload, which `sendBeacon` would
  // also do but only via POST without custom headers (no CSRF token).
  beacon() {
    if (!this.hasUrlValue) return
    const progressMs = Math.floor(this.audioTarget.currentTime * 1000)
    this.fetchJson(this.urlValue, "PATCH", { progress_ms: progressMs }, { keepalive: true })
  }

  stopInterval() {
    if (this.intervalId !== null) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }
  }

  fetchJson(url, method, body, options = {}) {
    const headers = { "Content-Type": "application/json", "Accept": "application/json" }
    const tokenEl = document.querySelector('meta[name="csrf-token"]')
    if (tokenEl) headers["X-CSRF-Token"] = tokenEl.content
    fetch(url, { method, headers, body: JSON.stringify(body), ...options }).catch(() => {})
  }
}
