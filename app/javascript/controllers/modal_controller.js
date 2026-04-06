import { Controller } from "@hotwired/stimulus"

// Generic modal controller using the native <dialog> element.
//
// Usage:
//   <div data-controller="modal">
//     <button data-action="modal#open">Open</button>
//     <%= render "shared/modal", title: "Create Goal" do %>
//       ...modal body content...
//     <% end %>
//   </div>
//
// The modal can also be opened programmatically by dispatching
// a "modal:open" event on any element inside the controller scope.

export default class extends Controller {
  static targets = ["dialog"]

  open(e) {
    e?.preventDefault()
    this.dialogTarget.showModal()
  }

  close(e) {
    e?.preventDefault()
    this.dialogTarget.close()
  }

  // Close when clicking the backdrop (the ::backdrop pseudo-element
  // doesn't receive click events, but clicks on the <dialog> itself
  // outside the inner content area do).
  clickOutside(e) {
    if (e.target === this.dialogTarget) {
      this.dialogTarget.close()
    }
  }

  // Close on successful Turbo form submission inside the modal
  submitEnd(e) {
    if (e.detail.success) {
      this.dialogTarget.close()
    }
  }
}
