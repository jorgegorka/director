import { Controller } from "@hotwired/stimulus"

// Submits the controller's form when an input change fires `change->auto-submit#submit`.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
