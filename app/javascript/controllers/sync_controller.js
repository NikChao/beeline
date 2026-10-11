import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { enqueue, flush, all } from "lib/outbox"
import { app } from "lib/app"

const RETRY_EVERY = 30000

// Offline first. Forms marked data-offline save to the outbox on this device
// and are sent from there; this keeps the outbox moving whenever it can.
export default class extends Controller {
  static targets = [ "status" ]
  static values = { outbox: String, shelf: String, desk: String, worker: String, scope: String }

  connect() {
    this.#registerServiceWorker()
    this.refresh()
    this.sync()
    this.timer = setInterval(() => this.sync(), RETRY_EVERY)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  sync() {
    flush()
  }

  resume() {
    if (document.visibilityState === "visible") this.sync()
  }

  async refresh() {
    const items = await all()
    const refused = items.filter(item => item.failed).length

    this.statusTarget.hidden = !items.length
    this.statusTarget.textContent = refused ? `${refused} couldn't be saved` : `${items.length} waiting to sync`
    this.statusTarget.classList.toggle("sync-status--trouble", refused > 0)
  }

  async submit(event) {
    const form = event.target
    if (!form.matches("form[data-offline]") || event.defaultPrevented) return
    event.preventDefault()

    const body = new URLSearchParams(new FormData(form, event.submitter))
    const entry = await enqueue({
      url: form.action,
      contentType: "application/x-www-form-urlencoded;charset=UTF-8",
      body: body.toString(),
      ...describe(form, body)
    })
    form.dispatchEvent(new CustomEvent("outbox:queued", { bubbles: true }))

    // A sync already under way may have started before this was queued.
    let sent = await flush()
    if (!sent.has(entry.id)) sent = await flush()

    visit(sent.get(entry.id)?.url || await this.#whereItWaits(entry))
  }

  // Not sent yet: show it, optimistically, where it'll end up. Something the
  // server refused goes to the outbox, where its words can be copied.
  async #whereItWaits(entry) {
    const kept = (await all()).find(item => item.id === entry.id)

    if (kept?.failed) return `${this.outboxValue}?queued=1`
    return entry.publish || entry.kind === "publish" ? this.shelfValue : this.deskValue
  }

  #registerServiceWorker() {
    if (!this.workerValue || !("serviceWorker" in navigator)) return

    navigator.serviceWorker.register(this.workerValue, { scope: this.scopeValue }).then(async () => {
      const pages = JSON.parse(document.querySelector("meta[name=offline-pages]")?.content || "[]")
      const registration = await navigator.serviceWorker.ready
      registration.active?.postMessage({ type: "warm", urls: pages })
    })
  }
}

function describe(form, body) {
  const kind = form.dataset.offline

  if (kind === "publication") {
    return { kind: body.get("_method") === "delete" ? "unpublish" : "publish", title: form.dataset.offlineTitle }
  } else {
    return { kind, title: body.get("draft[title]"), author: body.get("draft[author]"), publish: body.has("publish") }
  }
}

// Pages the iOS app keeps for offline use run without Turbo Drive: the app
// decides where to show the next one.
function visit(url) {
  if (app.present) {
    app.show(url)
  } else if (window.beelineOffline) {
    location.assign(url)
  } else {
    Turbo.visit(url)
  }
}
