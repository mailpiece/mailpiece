import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!document.documentElement.requestFullscreen) {
      this.element.remove()
    }
  }

  toggle() {
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      document.documentElement.requestFullscreen()
    }
  }
}
