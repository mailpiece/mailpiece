import { Controller } from "@hotwired/stimulus"
import { submitForm } from "helpers/form_helpers"

const AUTOSAVE_INTERVAL = 3000

// Announces each save as it leaves and as it is answered (saving, then saved or failed), for whoever shows it.
export default class extends Controller {
  #timer

  // Lifecycle

  disconnect() {
    this.submit()
  }

  // Actions

  async submit() {
    if (this.#dirty) {
      await this.#save()
    }
  }

  // Asked for by the writer, so it saves whether or not a change is waiting.
  async submitNow(event) {
    event.preventDefault()
    await this.#save()
  }

  change(event) {
    if (event.target.form === this.element && !this.#dirty) {
      this.#scheduleSave()
    }
  }

  // Private

  #scheduleSave() {
    this.#timer = setTimeout(() => this.#save(), AUTOSAVE_INTERVAL)
  }

  async #save() {
    this.#resetTimer()
    this.dispatch("saving")

    try {
      const response = await submitForm(this.element)
      this.dispatch(response.ok ? "saved" : "failed")
    } catch (error) {
      this.dispatch("failed")
      throw error
    }
  }

  #resetTimer() {
    clearTimeout(this.#timer)
    this.#timer = null
  }

  get #dirty() {
    return !!this.#timer
  }
}
