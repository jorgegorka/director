import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enable", "fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.fieldsTarget.hidden = !this.enableTarget.checked
  }
}
