import { Controller } from "@hotwired/stimulus"

// Download clicks never navigate the top window to GET /package.
// Status is polled at package/status until a current (non-stale) archive is
// ready, then the authorized GET runs in a hidden iframe so a 302 to the
// signed blob URL does not replace the Pages UI. Stale/missing packages POST
// generate first.
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

  startDownload(event) {
    if (this.pollValue) return

    event.preventDefault()
    this.beginDownload()
  }

  async beginDownload() {
    const data = await this.fetchStatus()
    if (data?.ready && data.download_url) {
      this.triggerDownload(data.download_url)
      this.showReady()
      return
    }

    await this.enqueueGenerate()
    this.pollValue = true
    this.showPreparing()
    this.startPolling()
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
      this.pollValue = false
      this.showFailure("Download is taking too long. Retry.")
      return
    }

    const data = await this.fetchStatus()
    if (!data) return

    if (data.ready && data.download_url) {
      this.stopPolling()
      this.pollValue = false
      this.triggerDownload(data.download_url)
      this.showReady()
      return
    }

    if (data.failed) {
      this.stopPolling()
      this.pollValue = false
      this.showFailure(data.failure_message || "Download failed. Retry.")
      return
    }

    if ((data.stale || data.state === "missing") && !this.requeued) {
      this.requeued = true
      await this.enqueueGenerate()
    }
  }

  async fetchStatus() {
    let response
    try {
      response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin"
      })
    } catch (_error) {
      return null
    }

    if (response.status === 401 || response.status === 403) {
      this.stopPolling()
      this.pollValue = false
      return null
    }
    if (!response.ok) return null

    return response.json()
  }

  async enqueueGenerate() {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    try {
      await fetch(this.downloadUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/html",
          "X-CSRF-Token": csrf || "",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin",
        redirect: "manual"
      })
    } catch (_error) {
      // Polling will retry status; user can click Download again.
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

  showReady() {
    const link = document.createElement("a")
    link.href = this.downloadUrlValue
    link.dataset.turbo = "false"
    link.className = this.linkClassName()
    link.textContent = "Download"
    this.element.replaceChildren(link)
  }

  showPreparing() {
    const button = document.createElement("button")
    button.type = "button"
    button.disabled = true
    button.className = this.linkClassName()
    button.textContent = "Preparing…"
    this.element.replaceChildren(button)
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
