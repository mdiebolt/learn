import { Controller } from "@hotwired/stimulus"

// PATCHes a single field's value to a URL whenever the bound input changes.
// Drop on any input/select/textarea with a `name`:
//
//   <select name="wpm"
//           data-controller="autosave"
//           data-autosave-url-value="<%= preferences_path %>"
//           data-action="autosave#patch">
//
// Sends `{ [name]: value }` as JSON with the page's CSRF token.
export default class extends Controller {
  static values = { url: String }

  patch({ target }) {
    if (!this.hasUrlValue || !target.name) return

    const headers = { "Content-Type": "application/json", "Accept": "application/json" }
    const tokenEl = document.querySelector('meta[name="csrf-token"]')
    if (tokenEl) headers["X-CSRF-Token"] = tokenEl.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ [target.name]: target.value })
    }).catch(() => {})
  }
}
