import { Controller } from "@hotwired/stimulus"

// The server reads where a draft goes and when. This has the main button say what the chosen destination does on the
// date picked, post to the resource that does it, and ask first when it mails the list or when a past date keeps it
// from being mailed. A bar whose button says what hour it is now is a scheduled post's. The words and the addresses come
// from the markup.
export default class extends Controller {
  static targets = [ "primary", "action", "destination", "day", "hour", "shown" ]

  connect() {
    this.choose()
  }

  choose() {
    const destination = this.destinationTargets.find(destination => destination.checked)

    if (destination) {
      const { label, confirm, path } = this.#offer(destination.dataset)

      this.actionTarget.textContent = label
      this.primaryTarget.setAttribute("formaction", path)

      if (confirm) {
        this.primaryTarget.dataset.turboConfirm = confirm
      } else {
        delete this.primaryTarget.dataset.turboConfirm
      }
    }
  }

  // A box's buttons submit a form the box is not inside, so it never hears turbo:submit-end itself. The button
  // answered is told, and a box hears its own: a background save, which no button sent, leaves an open box alone.
  submitted({ detail: { success, formSubmission: { submitter } } }) {
    if (success && submitter) this.dispatch("submitted", { target: submitter })
  }

  #offer(words) {
    if (this.primaryTarget.dataset.now) {
      return this.#scheduledOffer(words)
    } else {
      return this.#draftOffer(words)
    }
  }

  #scheduledOffer({ scheduleLabel, scheduleConfirm, pastLabel, pastConfirm }) {
    const { now, schedulePath, publicationPath } = this.primaryTarget.dataset

    if (this.#picked > now) {
      return { label: scheduleLabel, confirm: scheduleConfirm, path: schedulePath }
    } else {
      return { label: pastLabel, confirm: pastConfirm, path: publicationPath }
    }
  }

  #draftOffer({ label, confirm, scheduleLabel, pastLabel, pastConfirm }) {
    const { releasePath, schedulePath, publicationPath } = this.primaryTarget.dataset

    if (this.#picked < this.shownTarget.value) {
      return { label: pastLabel, confirm: pastConfirm, path: publicationPath }
    } else if (this.#picked > this.shownTarget.value) {
      return { label: scheduleLabel, path: schedulePath }
    } else {
      return { label, confirm, path: releasePath }
    }
  }

  // Written as the server writes the date shown, so the two compare as text.
  get #picked() {
    if (this.dayTarget.value) {
      return `${this.dayTarget.value}T${this.hourTarget.value.padStart(2, "0")}:00`
    } else {
      return this.primaryTarget.dataset.now || this.shownTarget.value
    }
  }
}
