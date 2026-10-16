import { Controller } from "@hotwired/stimulus"

// Says in the bar what has become of the writer's changes, over the line that says when the post was
// last touched. A background save is heard from the auto-save controller, which announces it as it
// leaves and as it is answered. The words come from the markup.
export default class extends Controller {
  static targets = [ "label" ]
  static values = { dirty: String, saving: String, saved: String, failed: String }

  #changedSinceSave = false

  // Only a field of the record being written counts: the bar's own fields are named outside it.
  changed({ target }) {
    if (/^\w+\[/.test(target.getAttribute("name"))) {
      this.#changedSinceSave = true
      this.#show("dirty")
    }
  }

  save(event) {
    event.preventDefault()
    this.element.requestSubmit()
  }

  saving() {
    this.#changedSinceSave = false
    this.#show("saving")
  }

  // What was typed while the save was on its way is not in it.
  saved() {
    this.#show(this.#changedSinceSave ? "dirty" : "saved")
  }

  failed() {
    this.#show("failed")
  }

  // The buttons that open the release choices and send a test save too, and leave the editor on the screen.
  submitting() {
    this.#changedSinceSave = false
  }

  submitted({ detail: { success } }) {
    if (success && this.element.dataset.saveState && !this.#changedSinceSave) {
      this.#show("saved")
    }
  }

  #show(state) {
    this.element.dataset.saveState = state
    this.labelTarget.textContent = this[`${state}Value`]
  }
}
