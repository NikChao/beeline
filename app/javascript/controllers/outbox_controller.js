import { Controller } from "@hotwired/stimulus"

const KINDS = { page: "New page", draft: "New draft", publication: "Publish", mark: "Mark" }

export default class extends Controller {
  static targets = [ "list", "empty", "template", "queued", "unavailable" ]

  async connect() {
    const params = new URLSearchParams(location.search)
    this.queuedTarget.hidden = !params.has("queued")
    this.unavailableTarget.hidden = !params.has("unavailable")

    const registration = await navigator.serviceWorker?.ready
    registration?.active?.postMessage({ type: "outbox" })
  }

  render({ detail: { items } }) {
    this.listTarget.replaceChildren(...items.map(item => this.#itemFor(item)))
    this.emptyTarget.hidden = items.length > 0
    if (!items.length) this.queuedTarget.hidden = true
  }

  async discard({ params: { id } }) {
    if (!confirm("Discard this for good?")) return

    const registration = await navigator.serviceWorker.ready
    registration.active?.postMessage({ type: "discard", id })
  }

  #itemFor(item) {
    const element = this.templateTarget.content.firstElementChild.cloneNode(true)
    const field = name => element.querySelector(`[data-field=${name}]`)
    const label = item.publish ? `${KINDS[item.kind]}, to publish` : KINDS[item.kind]
    const saved = new Date(item.queuedAt).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })

    field("title").textContent = item.title || (item.kind === "mark" ? "A mark on a draft" : item.kind === "publication" ? "Publishing a draft" : "Untitled")
    field("meta").textContent = item.failed
      ? `${label} · the host refused it (${item.status}). Your words are below, so you can copy them.`
      : `${label} · saved on this device ${saved}`

    if (item.failed) {
      field("text").textContent = new DOMParser().parseFromString(item.text || "", "text/html").body.innerText
      field("text").hidden = false
      field("discard").hidden = false
      field("discard").dataset.outboxIdParam = item.id
    }

    return element
  }
}
