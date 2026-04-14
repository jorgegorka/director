import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "row", "flag", "date", "interval", "unit"]

  connect() {
    this.#render()
  }

  enable(event) {
    event.preventDefault()
    this.flagTarget.value = "1"
    this.#render()
    this.dateTarget.focus()
  }

  clear(event) {
    event.preventDefault()
    this.flagTarget.value = "0"
    this.dateTarget.value = ""
    this.intervalTarget.value = 1
    this.unitTarget.value = "week"
    this.#render()
  }

  #render() {
    const on = this.flagTarget.value === "1"
    this.rowTarget.hidden = !on
    this.triggerTarget.hidden = on
  }
}
