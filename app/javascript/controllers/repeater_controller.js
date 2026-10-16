import { Controller } from "@hotwired/stimulus"

// Stands in the template for the row's number, which the server writes into its own rows' labels.
const ROW_NUMBER = "ROW_NUMBER"

export default class extends Controller {
  static targets = [ "list", "template", "row" ]

  // A removed row leaves a gap in the indexes, so a new row takes the next unused one rather than the count.
  #nextIndex = 0

  connect() {
    this.#nextIndex = this.rowTargets.length
  }

  add() {
    const [ row ] = this.#buildRow().children
    this.listTarget.appendChild(row)
    row.querySelector("input, textarea, select")?.focus()
  }

  remove(event) {
    const row = this.rowTargets.find(row => row.contains(event.target))
    const neighbour = row.nextElementSibling || row.previousElementSibling || this.element

    row.remove()
    neighbour.querySelector("input, textarea, select, [data-action~='repeater#add']")?.focus()
  }

  #buildRow() {
    const index = this.#nextIndex++
    const row = this.templateTarget.content.cloneNode(true)

    row.querySelectorAll("[name*='[ROW]']").forEach(field => {
      field.name = field.name.replace("[ROW]", `[${index}]`)
    })

    row.querySelectorAll(`[aria-label*='${ROW_NUMBER}']`).forEach(element => {
      element.setAttribute("aria-label", element.getAttribute("aria-label").replace(ROW_NUMBER, index + 1))
    })

    return row
  }
}
