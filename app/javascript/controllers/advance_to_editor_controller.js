import { Controller } from "@hotwired/stimulus"

// Enter in a one-line field goes on to the editor below it instead of breaking the line.
export default class extends Controller {
  static targets = [ "editor" ]

  advance(event) {
    event.preventDefault()
    this.editorTarget.focus()
  }
}
