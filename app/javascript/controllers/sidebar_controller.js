import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "sidebar-expanded"

export default class extends Controller {
  static targets = ["section", "drawer", "backdrop"]

  connect() {
    this.restoreState()
    this.markActive()
  }

  toggle(event) {
    const section = event.currentTarget.closest("[data-sidebar-target='section']")
    if (!section) return

    section.classList.toggle("sidebar__section--expanded")
    this.saveState()
  }

  openDrawer() {
    this.drawerTarget.classList.add("sidebar--open")
    this.backdropTarget.classList.add("sidebar__backdrop--visible")
    document.body.style.overflow = "hidden"
  }

  closeDrawer() {
    this.drawerTarget.classList.remove("sidebar--open")
    this.backdropTarget.classList.remove("sidebar__backdrop--visible")
    document.body.style.overflow = ""
  }

  // --- Private ---

  saveState() {
    const expanded = this.sectionTargets
      .filter(s => s.classList.contains("sidebar__section--expanded"))
      .map(s => s.dataset.sectionId)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(expanded))
  }

  restoreState() {
    let expanded
    try {
      expanded = JSON.parse(localStorage.getItem(STORAGE_KEY))
    } catch {
      return
    }
    if (!Array.isArray(expanded)) return

    this.sectionTargets.forEach(section => {
      if (expanded.includes(section.dataset.sectionId)) {
        section.classList.add("sidebar__section--expanded")
      }
    })
  }

  markActive() {
    const path = window.location.pathname
    const search = window.location.search

    // Mark active sub-links
    this.element.querySelectorAll(".sidebar__link").forEach(link => {
      const href = link.getAttribute("href")
      if (this.isActiveLink(href, path, search)) {
        link.classList.add("sidebar__link--active")
        // Auto-expand parent section
        const section = link.closest("[data-sidebar-target='section']")
        if (section) {
          section.classList.add("sidebar__section--expanded")
          const toggle = section.querySelector(".sidebar__toggle")
          if (toggle) toggle.classList.add("sidebar__toggle--active")
        }
      }
    })

    // Mark active direct links (e.g. Audit Log)
    this.element.querySelectorAll(".sidebar__direct-link").forEach(link => {
      const href = link.getAttribute("href")
      if (this.isActiveLink(href, path, search)) {
        link.classList.add("sidebar__direct-link--active")
      }
    })
  }

  isActiveLink(href, currentPath, currentSearch) {
    if (!href) return false
    try {
      const url = new URL(href, window.location.origin)
      if (url.pathname !== currentPath) return false
      // If the link has query params, they must match too
      if (url.search && url.search !== currentSearch) return false
      // If the link has no query params, match on path alone
      return true
    } catch {
      return false
    }
  }
}
