import { Controller } from "@hotwired/stimulus"

// Registers the service worker, hands it pages worth keeping for offline use,
// and shows when there are pages waiting to be sent.
export default class extends Controller {
  static targets = [ "status", "count" ]
  static values = { worker: String, scope: String }

  async connect() {
    if (!("serviceWorker" in navigator)) return

    this.received = event => this.#receive(event.data)
    navigator.serviceWorker.addEventListener("message", this.received)
    this.#reflectConnection()

    await navigator.serviceWorker.register(this.workerValue, { scope: this.scopeValue })
    this.#post({ type: "warm", urls: this.#pagesToKeep })
    this.#post({ type: navigator.onLine ? "sync" : "outbox" })
  }

  disconnect() {
    navigator.serviceWorker?.removeEventListener("message", this.received)
  }

  online() {
    this.#reflectConnection()
    this.#post({ type: "sync" })
  }

  offline() {
    this.#reflectConnection()
  }

  #receive({ type, items }) {
    if (type !== "outbox") return

    const waiting = items.filter(item => !item.failed).length
    this.countTarget.textContent = items.length ? `${items.length} waiting` : ""
    this.statusTarget.hidden = !items.length && navigator.onLine
    this.statusTarget.classList.toggle("masthead__status--trouble", items.length > waiting)

    window.dispatchEvent(new CustomEvent("outbox:changed", { detail: { items } }))
  }

  #reflectConnection() {
    this.element.classList.toggle("offline", !navigator.onLine)
    if (!navigator.onLine) this.statusTarget.hidden = false
  }

  async #post(message) {
    const registration = await navigator.serviceWorker.ready
    registration.active?.postMessage(message)
  }

  get #pagesToKeep() {
    return JSON.parse(document.querySelector("meta[name=offline-pages]")?.content || "[]")
  }
}
