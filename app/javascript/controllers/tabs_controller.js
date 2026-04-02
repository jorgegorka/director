import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]

  activate(event) {
    this.tabTargets.forEach(tab => tab.classList.remove("dashboard-tab--active"))
    event.currentTarget.classList.add("dashboard-tab--active")
  }
}
