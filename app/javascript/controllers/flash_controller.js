import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => {
      this.element.style.opacity = "0"
      setTimeout(() => this.element.hidden = true, 300)
    }, 8000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
