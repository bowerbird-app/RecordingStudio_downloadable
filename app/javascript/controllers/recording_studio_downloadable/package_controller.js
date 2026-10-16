import { Controller } from "@hotwired/stimulus"

// Download clicks never navigate the top window to GET /package.
// Status is polled at package/status until a current (non-stale) archive is
// ready, then the authorized GET runs in a hidden iframe so a 302 to the
// signed blob URL does not replace the Pages UI. A 409 from that GET carries
// continuation_url. The page can cancel
// recording-studio-downloadable:download-gate and open its own UI; otherwise
// the top window follows continuation_url. The form is never loaded in the
// hidden iframe. Stale/missing packages POST
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
    this.downloadStarted = false

    if (this.autoDownloadValue && this.downloadUrlValue && !this.pollValue) {
      this.beginDownload()
      return
    }

    if (this.pollValue) this.startPolling()
  }

  disconnect() {
    this.stopPolling()
    if (this.readyHold) {
      window.clearTimeout(this.readyHold)
      this.readyHold = null
    }
  }

  startDownload(event) {
    if (this.pollValue || this.downloadStarted) return

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

    this.showProgress(data.state)

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
    iframe.addEventListener("load", () => this.leaveForDownloadGate(iframe))
    iframe.src = url
    document.body.appendChild(iframe)
    window.setTimeout(() => iframe.remove(), 60_000)
  }

  leaveForDownloadGate(iframe) {
    let continuationUrl
    try {
      const text = iframe.contentDocument?.body?.innerText || ""
      const start = text.indexOf("{")
      const end = text.lastIndexOf("}")
      if (start === -1 || end <= start) return

      continuationUrl = JSON.parse(text.slice(start, end + 1)).continuation_url
    } catch (_error) {
      return
    }

    if (typeof continuationUrl !== "string" || continuationUrl.length === 0) return

    iframe.remove()
    if (this.holdDownloadGate(continuationUrl)) return

    window.top.location.assign(continuationUrl)
  }

  holdDownloadGate(continuationUrl) {
    const event = new CustomEvent("recording-studio-downloadable:download-gate", {
      bubbles: true,
      cancelable: true,
      detail: { continuationUrl }
    })
    this.element.dispatchEvent(event)
    return event.defaultPrevented
  }

  showReady() {
    if (this.showProgress("ready")) {
      this.holdReadyBriefly()
      return
    }

    this.replaceWithLink(this.downloadUrlValue, this.readyTextValue, { turbo: "false" })
  }

  showPreparing() {
    if (this.showProgress("pending")) return

    const button = document.createElement("button")
    button.type = "button"
    button.disabled = true
    button.className = this.linkClassName()
    button.textContent = this.preparingTextValue
    this.element.replaceChildren(button)
  }

  showProgress(state) {
    const panel = this.element.querySelector("[data-downloadable-progress]")
    if (!panel) return false

    panel.hidden = false
    const started = this.element.querySelector("[data-downloadable-started]")
    if (started) started.hidden = true

    const marks = {
      missing: [20, "Getting your files together."],
      stale: [20, "Getting your files together."],
      pending: [35, "Waiting to build the ZIP."],
      processing: [70, "Building the ZIP."],
      ready: [100, "Preparing"]
    }
    const [value, label] = marks[state] || marks.missing
    const bar = panel.querySelector("[role='progressbar']")
    const fill = bar?.firstElementChild
    const labelEl = panel.querySelector("[data-downloadable-progress-label]")
    const heading = labelEl?.matches("h1, h2, h3, h4, h5, h6")
      ? labelEl
      : labelEl?.querySelector("h1, h2, h3, h4, h5, h6")

    if (heading) heading.textContent = label
    if (bar) {
      bar.setAttribute("aria-valuenow", String(value))
      bar.setAttribute("aria-label", label)
    }
    if (fill) {
      fill.style.width = `${value}%`
      const sr = fill.querySelector(".sr-only")
      if (sr) sr.textContent = `${value}%`
    }

    return true
  }

  holdReadyBriefly() {
    if (this.readyHold) return

    this.readyHold = window.setTimeout(() => {
      this.readyHold = null
      this.revealDownloadStarted()
    }, 900)
  }

  revealDownloadStarted() {
    const started = this.element.querySelector("[data-downloadable-started]")
    if (!started || !this.element.isConnected) return

    this.downloadStarted = true
    const progress = this.element.querySelector("[data-downloadable-progress]")
    if (progress) progress.hidden = true
    started.hidden = false
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
