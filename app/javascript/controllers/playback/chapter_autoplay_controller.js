import { Controller } from "@hotwired/stimulus"

// Two responsibilities, both triggered by playback events on the same
// wrapper:
//   1. If we arrived with `?autoplay=1` (set by a prior chapter's
//      advance), start playing once metadata is ready.
//   2. When the playback controller signals end-of-chapter, navigate to
//      the next chapter URL with `?autoplay=1` so the cycle continues.
export default class extends Controller {
  static outlets = ["playback--playback"]
  static values = {
    autoplay: Boolean,
    nextChapterUrl: String
  }

  onLoadedMetadata() {
    if (!this.autoplayValue) return
    if (this.hasPlaybackPlaybackOutlet) this.playbackPlaybackOutlet.play()
  }

  // Prefer a Turbo Frame swap when our wrapper frame is present: it
  // replaces only the frame's contents, leaving <html> untouched, so
  // document-level fullscreen survives the transition. Fall back to a
  // full visit (e.g. if the frame markup is ever removed).
  //
  // The frame is fetched with `?autoplay=1` so the server-rendered view
  // for the new chapter starts playing on load. After the frame swap
  // succeeds we push a *clean* URL to history — no query param — so
  // reloads and bookmarks don't re-trigger autoplay.
  advance() {
    if (!this.nextChapterUrlValue) return
    const targetUrl = new URL(this.nextChapterUrlValue, window.location.origin)
    const fetchUrl = new URL(targetUrl)
    fetchUrl.searchParams.set("autoplay", "1")

    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.addEventListener("turbo:frame-load", () => {
        window.history.pushState({}, "", targetUrl.toString())
      }, { once: true })
      frame.src = fetchUrl.toString()
    } else {
      window.Turbo.visit(fetchUrl.toString())
    }
  }
}
