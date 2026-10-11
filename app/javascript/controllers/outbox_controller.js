import { Controller } from "@hotwired/stimulus"
import { all, discard } from "lib/outbox"

const KINDS = { page: "New page", draft: "New draft", publish: "Publish", unpublish: "Unpublish", mark: "Mark" }

export default class extends Controller {
  static targets = [ "list", "empty", "template", "queued", "unavailable" ]

  connect() {
    const params = new URLSearchParams(location.search)
    this.queuedTarget.hidden = !params.has("queued")
    this.unavailableTarget.hidden = !params.has("unavailable")
    this.render()
  }

  async render() {
    const items = await all()

    this.listTarget.replaceChildren(...items.map(item => this.#itemFor(item)))
    this.emptyTarget.hidden = items.length > 0
    if (!items.length) this.queuedTarget.hidden = true
  }

  async discard({ params: { id } }) {
    if (confirm("Discard this for good?")) await discard(id)
  }

  #itemFor(item) {
    const element = this.templateTarget.content.firstElementChild.cloneNode(true)
    const field = name => element.querySelector(`[data-field=${name}]`)
    const label = item.publish ? `${KINDS[item.kind]}, to publish` : KINDS[item.kind]
    const saved = new Date(item.queuedAt).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })

    field("title").textContent = item.title || { mark: "A mark on a draft", publish: "Publishing a draft", unpublish: "Unpublishing a paper" }[item.kind] || "Untitled"
    field("meta").textContent = item.failed
      ? `${label} · the server refused it (${item.status}). Your words are below, so you can copy them.`
      : `${label} · saved on this device ${saved}, waiting to sync`

    const html = item.contentType.includes("json") ? "" : new URLSearchParams(item.body).get("draft[body]") || ""
    field("text").textContent = new DOMParser().parseFromString(html, "text/html").body.innerText
    field("text").hidden = !html
    element.id = `entry-${item.id}`

    if (item.failed) {
      field("discard").hidden = false
      field("discard").dataset.outboxIdParam = item.id
    }

    return element
  }
}
