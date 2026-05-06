import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "playButton", "playIcon", "progress", "currentTime", "speedSelect"]
  static values = { timestamps: Array }

  connect() {
    this.currentWordIndex = -1
  }

  toggle() {
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  onPlay() {
    this.playIconTarget.textContent = "⏸"
  }

  onPause() {
    this.playIconTarget.textContent = "▶"
  }

  onTimeUpdate() {
    const time = this.audioTarget.currentTime
    const duration = this.audioTarget.duration

    if (duration) {
      const percent = (time / duration) * 100
      this.progressTarget.style.width = `${percent}%`
    }

    this.currentTimeTarget.textContent = this.formatTime(time)
    this.updateCurrentWord(time)
  }

  updateCurrentWord(time) {
    const index = this.timestampsValue.findIndex((t, i) => {
      const next = this.timestampsValue[i + 1]
      return time >= t.start && (!next || time < next.start)
    })

    if (index !== -1 && index !== this.currentWordIndex) {
      this.currentWordIndex = index
      this.dispatch("wordChange", { detail: this.timestampsValue[index] })
    }
  }

  seek(event) {
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    this.audioTarget.currentTime = this.audioTarget.duration * percent
  }

  setSpeed(event) {
    this.audioTarget.playbackRate = parseFloat(event.target.value)
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}
