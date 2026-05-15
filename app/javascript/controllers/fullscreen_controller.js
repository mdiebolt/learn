import { Controller } from "@hotwired/stimulus"

// Toggles browser fullscreen on the document so it persists across Turbo
// Drive navigations. Bind `toggle` to a button click and `toggleFromKey`
// to a `keydown.f@window` action for the keyboard shortcut.
export default class extends Controller {
  toggle() {
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      document.documentElement.requestFullscreen().catch(() => {})
    }
  }

  toggleFromKey(event) {
    if (document.activeElement && document.activeElement !== document.body) return
    event.preventDefault()
    this.toggle()
  }
}
