import { Controller } from "@hotwired/stimulus"

// Generic pill + popover picker. Two modes:
//
// 1. Options mode — panel contains clickable option buttons. Click sets the
//    value + label, closes the panel, and writes to a hidden input.
//
// 2. Free-input mode — panel contains a single <input> (e.g. datetime-local)
//    whose value drives the hidden input. Label is formatted from the raw
//    value via the formatValue (e.g. "date").
//
// Common behavior: outside-click closes, ESC closes, Arrow keys + Enter
// navigate options, optional search input filters options.
export default class extends Controller {
  static targets = ["trigger", "label", "panel", "input", "option", "search", "empty", "freeInput"]
  static values = { placeholder: String, format: String }

  connect() {
    this.onDocumentClick = this.onDocumentClick.bind(this)
    document.addEventListener("click", this.onDocumentClick)
    this.syncFromInput()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  toggle(event) {
    event.preventDefault()
    if (this.panelTarget.hidden) this.open()
    else this.close()
  }

  open() {
    this.panelTarget.hidden = false
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.runFilter()
      queueMicrotask(() => this.searchTarget.focus())
    } else if (this.hasFreeInputTarget) {
      queueMicrotask(() => this.freeInputTarget.focus())
    } else {
      const first = this.optionTargets.find((o) => !o.hidden)
      queueMicrotask(() => first?.focus())
    }
  }

  close(event) {
    event?.preventDefault()
    this.panelTarget.hidden = true
  }

  select(event) {
    event.preventDefault()
    const el = event.currentTarget
    const value = el.dataset.popoverPickerValueParam ?? ""
    const label = el.dataset.popoverPickerLabelParam ?? el.textContent.trim()
    this.setValue(value, label)
    this.close()
    this.triggerTarget.focus()
  }

  clear(event) {
    event.preventDefault()
    event.stopPropagation()
    this.setValue("", this.placeholderValue)
    if (this.hasFreeInputTarget) this.freeInputTarget.value = ""
    this.close()
    this.triggerTarget.focus()
  }

  applyFreeInput() {
    if (!this.hasFreeInputTarget) return
    const raw = this.freeInputTarget.value
    if (raw) {
      this.setValue(raw, this.formatLabel(raw))
    } else {
      this.setValue("", this.placeholderValue)
    }
  }

  filter() {
    this.runFilter()
  }

  runFilter() {
    if (!this.hasSearchTarget) return
    const query = this.searchTarget.value.trim().toLowerCase()
    let shown = 0
    this.optionTargets.forEach((opt) => {
      const haystack = (opt.dataset.popoverPickerLabelParam || opt.textContent).toLowerCase()
      const match = !query || haystack.includes(query)
      opt.hidden = !match
      if (match) shown += 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }

  keydown(event) {
    const visible = this.optionTargets.filter((o) => !o.hidden)
    const idx = visible.indexOf(document.activeElement)
    switch (event.key) {
      case "Escape":
        event.preventDefault()
        this.close()
        this.triggerTarget.focus()
        break
      case "ArrowDown":
        if (visible.length === 0) return
        event.preventDefault()
        visible[(idx + 1) % visible.length]?.focus()
        break
      case "ArrowUp":
        if (visible.length === 0) return
        event.preventDefault()
        visible[(idx - 1 + visible.length) % visible.length]?.focus()
        break
      case "Enter":
        event.preventDefault()
        if (idx >= 0) {
          visible[idx].click()
        } else if (visible.length === 1) {
          visible[0].click()
        }
        break
    }
  }

  onDocumentClick(event) {
    if (!this.panelTarget.hidden && !this.element.contains(event.target)) {
      this.close()
    }
  }

  // Internal helpers

  setValue(value, label) {
    this.inputTarget.value = value
    this.labelTarget.textContent = label || this.placeholderValue
    this.triggerTarget.classList.toggle("pill-btn--set", Boolean(value))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncFromInput() {
    const value = this.inputTarget.value
    if (!value) {
      this.labelTarget.textContent = this.placeholderValue
      this.triggerTarget.classList.remove("pill-btn--set")
      return
    }

    if (this.hasFreeInputTarget) {
      this.labelTarget.textContent = this.formatLabel(value)
      this.triggerTarget.classList.add("pill-btn--set")
      return
    }

    const match = this.optionTargets.find(
      (o) => String(o.dataset.popoverPickerValueParam) === String(value)
    )
    this.labelTarget.textContent =
      match?.dataset.popoverPickerLabelParam || match?.textContent.trim() || this.placeholderValue
    this.triggerTarget.classList.toggle("pill-btn--set", Boolean(match))
  }

  formatLabel(raw) {
    if (this.formatValue === "date" && raw) {
      // Accepts "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM"
      const iso = raw.length === 10 ? `${raw}T00:00:00` : raw
      const d = new Date(iso)
      if (!isNaN(d)) {
        return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })
      }
    }
    return raw
  }
}
