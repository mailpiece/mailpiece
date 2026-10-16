import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Refreshes the page until this element is gone, for a wait whose broadcast may land before the page subscribes.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5 } }

  #timer

  connect() {
    this.#timer = setInterval(() => this.#reload(), this.intervalValue * 1000)
  }

  disconnect() {
    clearInterval(this.#timer)
  }

  #reload() {
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
