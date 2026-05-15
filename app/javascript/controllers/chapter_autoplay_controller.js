import { Controller } from "@hotwired/stimulus"

// Two responsibilities, both triggered by playback events on the same
// wrapper:
//   1. If we arrived with `?autoplay=1` (set by a prior chapter's
//      advance), start playing once metadata is ready.
//   2. When the playback controller signals end-of-chapter, navigate to
//      the next chapter URL with `?autoplay=1` so the cycle continues.
export default class extends Controller {
  static outlets = ["playback"]
  static values = {
    autoplay: Boolean,
    nextChapterUrl: String
  }

  onLoadedMetadata() {
    if (!this.autoplayValue) return
    if (this.hasPlaybackOutlet) this.playbackOutlet.play()
  }

  // Prefer a Turbo Frame swap when our wrapper frame is present: it
  // replaces only the frame's contents, leaving <html> untouched, so
  // document-level fullscreen survives the transition. Fall back to a
  // full visit (e.g. if the frame markup is ever removed).
  advance() {
    if (!this.nextChapterUrlValue) return
    const url = new URL(this.nextChapterUrlValue, window.location.origin)
    url.searchParams.set("autoplay", "1")
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.src = url.toString()
    } else {
      window.Turbo.visit(url.toString())
    }
  }
}
