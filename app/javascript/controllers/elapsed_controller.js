import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { startedAt: String }
  static targets = ["display"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const started = new Date(this.startedAtValue)
    const elapsed = Math.floor((Date.now() - started.getTime()) / 1000)

    this.displayTarget.textContent = this.format(elapsed)
  }

  format(totalSeconds) {
    if (totalSeconds < 0) return "0s"

    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    if (hours > 0) return `${hours}h ${minutes}m`
    if (minutes > 0) return `${minutes}m ${seconds}s`
    return `${seconds}s`
  }
}
