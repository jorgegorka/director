import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["configGroup"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedType = this.element.querySelector("[data-adapter-config-select]").value
    this.configGroupTargets.forEach(group => {
      if (group.dataset.adapterType === selectedType) {
        group.style.display = ""
        // Enable inputs so they submit
        group.querySelectorAll("input, select, textarea").forEach(el => el.disabled = false)
      } else {
        group.style.display = "none"
        // Disable hidden inputs so they don't submit
        group.querySelectorAll("input, select, textarea").forEach(el => el.disabled = true)
      }
    })
  }
}
