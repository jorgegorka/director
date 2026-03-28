import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: { type: String, default: "overview" } }

  connect() {
    this.showTab(this.activeTabValue)
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tab
    this.showTab(tabName)
  }

  showTab(name) {
    this.tabTargets.forEach((tab) => {
      if (tab.dataset.tab === name) {
        tab.classList.add("dashboard-tab--active")
      } else {
        tab.classList.remove("dashboard-tab--active")
      }
    })

    this.panelTargets.forEach((panel) => {
      if (panel.dataset.tabName === name) {
        panel.removeAttribute("hidden")
      } else {
        panel.setAttribute("hidden", "")
      }
    })
  }
}
