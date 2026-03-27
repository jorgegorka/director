import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.toggleAttribute("hidden")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.panelTarget.setAttribute("hidden", "")
    }
  }

  connect() {
    this.clickOutsideHandler = this.close.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }
}
