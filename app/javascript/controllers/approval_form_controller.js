import { Controller } from "@hotwired/stimulus"

// Shares a single feedback textarea between the approve (POST) and reject (DELETE)
// buttons. On click, copies the textarea's value into the target form's hidden
// feedback input and submits that form.
export default class extends Controller {
  static targets = ["feedback", "approveForm", "rejectForm", "approveFeedback", "rejectFeedback"]

  approve(event) {
    event.preventDefault()
    this.approveFeedbackTarget.value = this.feedbackTarget.value
    this.approveFormTarget.requestSubmit()
  }

  reject(event) {
    event.preventDefault()
    this.rejectFeedbackTarget.value = this.feedbackTarget.value
    this.rejectFormTarget.requestSubmit()
  }
}
