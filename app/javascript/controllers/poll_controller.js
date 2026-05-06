import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.poll()
  }

  disconnect() {
    this.stopPolling()
  }

  poll() {
    this.timer = setInterval(() => {
      fetch(this.urlValue, {
        headers: { "Accept": "text/vnd.turbo-stream.html" }
      })
      .then(response => {
        if (response.ok && response.headers.get("Content-Type")?.includes("turbo-stream")) {
          return response.text()
        }
        return null
      })
      .then(html => {
        if (html) {
          Turbo.renderStreamMessage(html)
          this.stopPolling()
        }
      })
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
