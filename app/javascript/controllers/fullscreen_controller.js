import { Controller } from "@hotwired/stimulus"

// Toggles browser fullscreen on the document so it persists across
// Turbo Drive navigations. Bind `toggle` to a button click and
// `onKeydown` to `keydown@window` to support a keyboard shortcut.
export default class extends Controller {
  toggle() {
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      document.documentElement.requestFullscreen().catch(() => {})
    }
  }

  onKeydown(event) {
    const active = document.activeElement
    if (active && active !== document.body) return
    if (event.key === "f" || event.key === "F") {
      event.preventDefault()
      this.toggle()
    }
  }
}
