import { Controller } from "@hotwired/stimulus"

// Download clicks never navigate the top window to GET /package.
// Status is polled at package/status until a current (non-stale) archive is
// ready, then the authorized GET runs in a hidden iframe so a 302 to the
// signed blob URL does not replace the Pages UI. Stale/missing packages POST
// generate when the actor is authorized for the download action.
export default class extends Controller {
  static values = {
    statusUrl: String,
    downloadUrl: String,
    poll: { type: Boolean, default: false },
    autoDownload: { type: Boolean, default: false },
    canGenerate: { type: Boolean, default: false },
    interval: { type: Number, default: 1000 },
    readyText: { type: String, default: "Download" },
    preparingText: { type: String, default: "Preparing…" },
    retryText: { type: String, default: "Retry download" },
    notReadyText: { type: String, default: "This download is not ready yet." },
    timeoutText: { type: String, default: "Download is taking too long. Retry." }
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

    if (this.canGenerateFrom(data)) {
      await this.enqueueGenerate()
      this.pollValue = true
      this.showPreparing()
      this.startPolling()
      return
    }

    this.showNotReady()
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
      this.showFailure(this.timeoutTextValue)
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
      this.showFailure(data.failure_message || this.retryTextValue)
      return
    }

    if ((data.stale || data.state === "missing") && !this.requeued && this.canGenerateFrom(data)) {
      this.requeued = true
      await this.enqueueGenerate()
    }
  }

  canGenerateFrom(data) {
    if (data && Object.prototype.hasOwnProperty.call(data, "can_generate")) {
      return !!data.can_generate
    }

    return this.canGenerateValue
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
    this.replaceWithLink(this.downloadUrlValue, this.readyTextValue, { turbo: "false" })
  }

  showPreparing() {
    const button = document.createElement("button")
    button.type = "button"
    button.disabled = true
    button.className = this.linkClassName()
    button.textContent = this.preparingTextValue
    this.element.replaceChildren(button)
  }

  showNotReady() {
    const button = document.createElement("button")
    button.type = "button"
    button.disabled = true
    button.className = this.linkClassName()
    button.textContent = this.notReadyTextValue
    this.element.replaceChildren(button)
  }

  showFailure(message) {
    this.replaceWithLink(this.downloadUrlValue, this.retryTextValue, { turboMethod: "post", title: message })
  }

  replaceWithLink(href, text, { turbo, turboMethod, title } = {}) {
    const link = document.createElement("a")
    link.href = href
    link.className = this.linkClassName()
    link.textContent = text
    if (turbo) link.dataset.turbo = turbo
    if (turboMethod) link.dataset.turboMethod = turboMethod
    if (title) link.title = title
    this.element.replaceChildren(link)
  }

  linkClassName() {
    return this.element.querySelector("a, button")?.className || "underline"
  }
}
