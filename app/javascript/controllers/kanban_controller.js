import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "column"]

  dragStart(event) {
    const card = event.currentTarget
    event.dataTransfer.setData("text/plain", card.dataset.taskId)
    event.dataTransfer.effectAllowed = "move"
    card.classList.add("kanban-card--dragging")
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("kanban-card--dragging")
    this.columnTargets.forEach(col => col.classList.remove("kanban__column--drag-over"))
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  dragEnter(event) {
    event.preventDefault()
    const column = event.currentTarget
    column.classList.add("kanban__column--drag-over")
  }

  dragLeave(event) {
    const column = event.currentTarget
    // Only remove if leaving the column itself, not entering a child
    if (!column.contains(event.relatedTarget)) {
      column.classList.remove("kanban__column--drag-over")
    }
  }

  drop(event) {
    event.preventDefault()
    const column = event.currentTarget
    column.classList.remove("kanban__column--drag-over")

    const taskId = event.dataTransfer.getData("text/plain")
    const newStatus = column.dataset.status
    const card = this.cardTargets.find(c => c.dataset.taskId === taskId)

    if (!card) return

    // Move card DOM element to new column
    const columnBody = column.querySelector(".kanban__column-body")
    columnBody.appendChild(card)

    // Update column counts
    this.#updateColumnCounts()

    // PATCH request to update task status
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    fetch(`/tasks/${taskId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html, text/html"
      },
      body: JSON.stringify({ task: { status: newStatus } })
    }).then(response => {
      if (!response.ok) {
        // Revert: reload page on failure
        window.location.reload()
      }
    })
  }

  #updateColumnCounts() {
    this.columnTargets.forEach(column => {
      const count = column.querySelectorAll(".kanban-card").length
      const countEl = column.querySelector(".kanban__column-count")
      if (countEl) countEl.textContent = count
    })
  }
}
