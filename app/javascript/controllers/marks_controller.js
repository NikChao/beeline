import { Controller } from "@hotwired/stimulus"
import { all } from "lib/outbox"
import { draw } from "lib/marks"

// The page as served only has the marks the server has. Marks still waiting
// in the outbox are drawn from there, so they're on the page wherever it's
// shown: back on the draft, beside the next one, from a kept copy offline.
export default class extends Controller {
  static values = { url: String }

  async connect() {
    // A page restored from Turbo's cache may already carry some.
    const shown = new Set(Array.from(this.element.querySelectorAll("[data-outbox-id]"), element => element.dataset.outboxId))

    for (const entry of await all()) {
      if (entry.kind !== "mark" || entry.url !== this.urlValue || entry.failed || shown.has(String(entry.id))) continue

      const { mark } = JSON.parse(entry.body)
      const points = []
      for (let index = 0; index < mark.points.length; index += 2) points.push(mark.points.slice(index, index + 2))

      draw(this.element, { ...mark, points }).dataset.outboxId = entry.id
    }
  }
}
