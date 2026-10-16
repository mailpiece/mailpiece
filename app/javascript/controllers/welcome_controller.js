import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.#welcoming = !this.#seen
  }

  // Turbo keeps <html> across visits, so the attribute would otherwise follow the reader to another newsletter's home.
  disconnect() {
    this.#welcoming = false
  }

  dismiss() {
    this.remember()
    this.#welcoming = false
  }

  remember() {
    localStorage.setItem(this.keyValue, "seen")
  }

  get #seen() {
    return localStorage.getItem(this.keyValue)
  }

  set #welcoming(welcoming) {
    document.documentElement.toggleAttribute("data-welcome", welcoming)
  }
}
