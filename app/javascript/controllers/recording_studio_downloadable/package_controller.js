import { Controller } from "@hotwired/stimulus"

// After POST /package the helper renders Preparing… and this controller.
// It polls GET /package/status (Accessible :download). When ready, it starts
// the authorized GET /package download so the ZIP lands without a manual refresh.
export default class extends Controller {
  static values = {
    statusUrl: String,
    downloadUrl: String,
    poll: { type: Boolean, default: false },
    autoDownload: { type: Boolean, default: false },
    interval: { type: Number, default: 1000 }
  }

  connect() {
    this.attempts = 0
    this.maxAttempts = 90

    if (this.autoDownloadValue && this.downloadUrlValue && !this.pollValue) {
      this.triggerDownload(this.downloadUrlValue)
      return
    }

    if (this.pollValue) this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.poll()
    this.timer = window.setInterval(() => this.poll(), this.intervalValue)
  }

  stopPolling() {
    if (!this.timer) return

    window.clearInterval(this.timer)
    this.timer = null
  }

  async poll() {
    this.attempts += 1
    if (this.attempts > this.maxAttempts) {
      this.stopPolling()
      this.showFailure("Download is taking too long. Retry.")
      return
    }

    let response
    try {
      response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin"
      })
    } catch (_error) {
      return
    }

    if (response.status === 401 || response.status === 403) {
      this.stopPolling()
      return
    }
    if (!response.ok) return

    const data = await response.json()
    if (data.ready && data.download_url) {
      this.stopPolling()
      this.triggerDownload(data.download_url)
      this.showReady(data.download_url)
      return
    }

    if (data.failed) {
      this.stopPolling()
      this.showFailure(data.failure_message || "Download failed. Retry.")
    }
  }

  triggerDownload(url) {
    const iframe = document.createElement("iframe")
    iframe.hidden = true
    iframe.setAttribute("data-turbo", "false")
    iframe.src = url
    document.body.appendChild(iframe)
    window.setTimeout(() => iframe.remove(), 60_000)
  }

  showReady(url) {
    const link = document.createElement("a")
    link.href = url
    link.dataset.turbo = "false"
    link.className = this.linkClassName()
    link.textContent = "Download"
    this.element.replaceChildren(link)
  }

  showFailure(message) {
    const link = document.createElement("a")
    link.href = this.downloadUrlValue
    link.dataset.turboMethod = "post"
    link.className = this.linkClassName()
    link.textContent = "Retry download"
    link.title = message
    this.element.replaceChildren(link)
  }

  linkClassName() {
    return this.element.querySelector("a, button")?.className || "underline"
  }
}
