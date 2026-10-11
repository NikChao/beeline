import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "beeline:fullscreen"
const THEME_COLORS = { desk: "#ebe5d8", paper: "#fbf8f1" }

// Lets the paper fill the screen while writing or marking up. The choice
// carries from page to page; the desk and the shelf keep their desk.
export default class extends Controller {
  static values = { enterLabel: String, leaveLabel: String }

  connect() {
    this.#show(localStorage.getItem(STORAGE_KEY) === "true")
  }

  disconnect() {
    this.#show(false)
  }

  toggle() {
    const fullscreen = !document.documentElement.classList.contains("fullscreen")
    localStorage.setItem(STORAGE_KEY, fullscreen)
    this.#show(fullscreen)
  }

  #show(fullscreen) {
    document.documentElement.classList.toggle("fullscreen", fullscreen)
    document.querySelector("meta[name=theme-color]")?.setAttribute("content", fullscreen ? THEME_COLORS.paper : THEME_COLORS.desk)
    this.element.setAttribute("aria-pressed", fullscreen)

    const label = fullscreen ? this.leaveLabelValue : this.enterLabelValue
    this.element.setAttribute("aria-label", label)
    this.element.title = label
  }
}
