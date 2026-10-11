import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "beeline:split"

export default class extends Controller {
  static targets = [ "option" ]
  static classes = [ "split" ]

  connect() {
    this.#show(localStorage.getItem(STORAGE_KEY) === "true")
  }

  choose({ params: { split } }) {
    localStorage.setItem(STORAGE_KEY, split)
    this.#show(split)
  }

  #show(split) {
    this.element.classList.toggle(this.splitClass, split)
    this.optionTargets.forEach(option => {
      option.setAttribute("aria-pressed", option.dataset.splitSplitParam === String(split))
    })
  }
}
