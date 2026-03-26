import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "trigger"]

  toggle() {
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  // Close when clicking outside
  connect() {
    this.clickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside)
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.hidden = true
    }
  }
}
