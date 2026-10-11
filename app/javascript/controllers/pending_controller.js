import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { all } from "lib/outbox"
import { app } from "lib/app"

// Optimistic: saves waiting in the outbox show on the desk and shelf straight
// away, marked as waiting. Once the outbox syncs, the page is fetched again.
export default class extends Controller {
  static targets = [ "list", "template" ]
  static values = { shelf: Boolean, outbox: String }

  connect() {
    this.render()
    // Other windows (an app tab, say) write to the same outbox.
    this.timer = setInterval(() => this.render(), 3000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async render() {
    const items = (await all()).filter(item => this.shelfValue ? item.publish || item.kind === "publish" : [ "page", "draft" ].includes(item.kind))

    this.listTarget.replaceChildren(...items.reverse().map(item => this.#itemFor(item)))
    this.element.hidden = !items.length
    this.showing = items.length > 0
  }

  refresh() {
    if (!this.showing) return

    if (window.beelineOffline) {
      app.reconnect()
    } else {
      Turbo.visit(location.href, { action: "replace" })
    }
  }

  #itemFor(item) {
    const element = this.templateTarget.content.firstElementChild.cloneNode(true)
    const field = name => element.querySelector(`[data-field=${name}]`)
    const params = item.contentType.includes("json") ? new URLSearchParams() : new URLSearchParams(item.body)
    const text = new DOMParser().parseFromString(params.get("draft[body]") || "", "text/html").body.textContent.trim()

    field("link").href = `${this.outboxValue}#entry-${item.id}`
    field("title").textContent = item.title || "Untitled"
    field("meta").textContent = [
      item.author,
      item.failed ? "couldn't be saved, see the outbox" : this.#waiting(item)
    ].filter(Boolean).join(" · ")
    field("excerpt").textContent = text.length > 200 ? `${text.slice(0, 200).replace(/\s+\S*$/, "")}…` : text

    element.classList.toggle("listing__item--trouble", Boolean(item.failed))
    return element
  }

  #waiting(item) {
    if (this.shelfValue) return "published on this device, waiting to sync"
    return `${item.kind === "draft" ? "New draft" : "New page"}${item.publish ? ", to publish" : ""} · waiting to sync`
  }
}
