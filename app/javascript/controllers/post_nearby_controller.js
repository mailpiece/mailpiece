import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "day", "hour", "frame" ]

  // The frame is lazy, so the posts are asked for when the menu around it first opens.
  connect() {
    this.load()
  }

  load() {
    if (this.dayTarget.value) {
      const url = new URL(this.frameTarget.dataset.address, window.location.href)

      url.searchParams.set("day", this.dayTarget.value)
      url.searchParams.set("hour", this.hourTarget.value)

      this.frameTarget.src = url.href
    }
  }
}
