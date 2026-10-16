import { Controller } from "@hotwired/stimulus"

// Keeps a gated download on this page. The Download button opens the modal
// through Flatpack. A 409 from the package iframe asks this controller to
// stay instead of sending the window to continuation_url.
export default class extends Controller {
  static values = { modalId: String }

  hold(event) {
    event.preventDefault()
    const modal = document.getElementById(this.modalIdValue)
    if (!modal) return

    this.application.getControllerForElementAndIdentifier(modal, "flat-pack--modal")?.open()
  }
}
