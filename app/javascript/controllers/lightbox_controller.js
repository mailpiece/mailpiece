import { Controller } from "@hotwired/stimulus"

// Adapted from Writebook (37signals, MIT licence).
export default class extends Controller {
  static targets = [ "image", "dialog", "zoomedImage" ]

  imageTargetConnected(element) {
    element.addEventListener("click", this.#open)
  }

  imageTargetDisconnected(element) {
    element.removeEventListener("click", this.#open)
  }

  // The dialog covers the page, so a click that misses the picture and the button lands on it.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  reset() {
    this.zoomedImageTarget.removeAttribute("src")
    this.zoomedImageTarget.alt = ""
  }

  // Without a dialog, or with a key held to open it elsewhere, the link is left to open the picture.
  #open = (event) => {
    if (!this.hasDialogTarget || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    this.#set(event.currentTarget)
    this.dialogTarget.showModal()
  }

  #set(link) {
    this.zoomedImageTarget.src = link.href
    this.zoomedImageTarget.alt = link.querySelector("img")?.alt || ""
  }
}
