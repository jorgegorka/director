import { Controller } from "@hotwired/stimulus"

// Apply persisted theme at import time so <html data-theme> is set before CSS
// resolves. Runs as a side effect of eager controller loading in index.js.
try {
  const persisted = localStorage.getItem("theme")
  if (persisted === "light" || persisted === "dark") {
    document.documentElement.dataset.theme = persisted
  }
} catch (_) { /* storage unavailable */ }

// Manual dark/light theme override. Persists to localStorage and sets
// data-theme on <html>. When no override is set, CSS falls back to
// prefers-color-scheme via :root:not([data-theme]).
export default class extends Controller {
  toggle() {
    const root = document.documentElement
    const current = root.dataset.theme
      || (window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark")
    const next = current === "light" ? "dark" : "light"
    root.dataset.theme = next
    try { localStorage.setItem("theme", next) } catch (_) { /* storage unavailable */ }
  }
}
