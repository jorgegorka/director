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
        // Respect the active provider sub-toggle within the visible group
        this.toggleProviderIn(group)
      } else {
        group.style.display = "none"
        // Disable hidden inputs so they don't submit
        group.querySelectorAll("input, select, textarea").forEach(el => el.disabled = true)
      }
    })
  }

  // Called from a provider <select>'s change event. Scopes the toggle to the
  // fieldset that contains the changed select.
  toggleProvider(event) {
    const group = event.target.closest("[data-adapter-type]")
    if (group) this.toggleProviderIn(group)
  }

  // Show/hide provider-scoped sub-groups inside a single adapter fieldset
  // based on the current value of that fieldset's [data-provider-select].
  toggleProviderIn(group) {
    const providerSelect = group.querySelector("[data-provider-select]")
    if (!providerSelect) return
    const active = providerSelect.value
    group.querySelectorAll("[data-provider-value]").forEach(sub => {
      const matches = sub.dataset.providerValue === active
      sub.style.display = matches ? "" : "none"
      sub.querySelectorAll("input, select, textarea").forEach(el => el.disabled = !matches)
    })
  }
}
