import { Controller } from "@hotwired/stimulus"
import { enqueue, flush } from "lib/outbox"
import { draw, pathData } from "lib/marks"

const TOOL_KEYS = { m: "line", p: "stroke", w: "word" }
const COLOR_KEYS = { 1: "red", 2: "green", 3: "yellow" }

// Draws on a page in page units: 1000 across, however wide the page renders.
export default class extends Controller {
  static targets = [ "page", "canvas", "tool", "color" ]
  static values = { url: String, tool: { type: String, default: "line" }, color: { type: String, default: "red" } }

  connect() {
    this.made = []

    // On touch screens, start with the pen down so a finger scrolls the page.
    if (matchMedia("(pointer: coarse)").matches) this.toolValue = ""
  }

  // Tray

  pick({ params: { tool, color } }) {
    if (tool) this.toolValue = this.toolValue === tool ? "" : tool
    if (color) this.colorValue = color
  }

  hotkey(event) {
    if (event.target.closest("input, textarea, [contenteditable]")) return
    const key = event.key.toLowerCase()

    if ((event.metaKey || event.ctrlKey) && key === "z") {
      event.preventDefault()
      this.undo()
    } else if (event.metaKey || event.ctrlKey || event.altKey) {
      return
    } else if (TOOL_KEYS[key]) {
      this.pick({ params: { tool: TOOL_KEYS[key] } })
    } else if (COLOR_KEYS[key]) {
      this.colorValue = COLOR_KEYS[key]
    } else if (key === "escape") {
      this.toolValue = ""
    }
  }

  toolValueChanged() {
    this.pageTarget.dataset.tool = this.toolValue
    this.toolTargets.forEach(button => button.setAttribute("aria-pressed", button.dataset.markupToolParam === this.toolValue))
  }

  colorValueChanged() {
    this.pageTarget.dataset.color = this.colorValue
    this.colorTargets.forEach(button => button.setAttribute("aria-pressed", button.dataset.markupColorParam === this.colorValue))
  }

  // Drawing

  start(event) {
    if (!this.toolValue || event.button !== 0 || event.target.closest(".marks__word-input")) return
    event.preventDefault()

    const point = this.#pointAt(event)

    if (this.toolValue === "word") {
      this.#placeWord(point)
    } else {
      const mark = { kind: this.toolValue, color: this.colorValue, points: [ point ] }
      this.drawing = { mark, element: this.#draw(mark) }
      this.pageTarget.setPointerCapture(event.pointerId)
    }
  }

  move(event) {
    if (!this.drawing) return

    const { mark, element } = this.drawing
    const point = this.#pointAt(event)

    if (mark.kind === "line") {
      const [ origin ] = mark.points
      mark.points = [ origin, [ point[0], origin[1] ] ]
    } else {
      const last = mark.points.at(-1)
      if (Math.hypot(point[0] - last[0], point[1] - last[1]) < 2) return
      mark.points.push(point)
    }

    element.setAttribute("d", pathData(mark.points))
  }

  end() {
    if (!this.drawing) return

    const { mark, element } = this.drawing
    this.drawing = null

    const [ first ] = mark.points
    const last = mark.points.at(-1)
    if (mark.points.length < 2 || Math.hypot(last[0] - first[0], last[1] - first[1]) < 4) {
      element.remove()
    } else {
      this.#save(mark, element)
    }
  }

  async undo() {
    const element = this.made.pop()
    if (!element) return

    element.remove()
    const response = await fetch(`${this.urlValue}/${element.dataset.markId}`, { method: "DELETE", headers: this.#headers }).catch(() => null)

    if (!response?.ok) {
      this.canvasTarget.append(element)
      this.made.push(element)
    }
  }

  // Private

  #placeWord(point) {
    this.wordInput?.remove()

    const input = document.createElement("input")
    input.className = `marks__word-input mark--${this.colorValue}`
    input.style.left = `${point[0] / 10}cqi`
    input.style.top = `${point[1] / 10}cqi`
    input.maxLength = 80
    input.setAttribute("aria-label", "Word to place")

    const finish = commit => {
      if (this.wordInput !== input) return
      this.wordInput = null
      const text = input.value.trim()
      input.remove()

      if (commit && text) {
        const mark = { kind: "word", color: this.colorValue, points: [ point ], text }
        this.#save(mark, this.#draw(mark))
      }
    }

    input.addEventListener("keydown", event => {
      if (event.key === "Enter") finish(true)
      if (event.key === "Escape") finish(false)
    })
    input.addEventListener("blur", () => finish(true))

    this.wordInput = input
    this.pageTarget.append(input)
    requestAnimationFrame(() => input.focus())
  }

  #draw(mark) {
    return draw(this.canvasTarget, mark)
  }

  // Marks go to the outbox like everything else. One that went straight
  // through can be taken back; one waiting to sync stays on the page.
  async #save(mark, element) {
    const entry = await enqueue({
      url: this.urlValue,
      contentType: "application/json",
      accept: "application/json",
      body: JSON.stringify({ mark: { ...mark, points: mark.points.flat() } }),
      kind: "mark"
    })
    element.dataset.outboxId = entry.id

    let sent = await flush()
    if (!sent.has(entry.id)) sent = await flush()

    const response = sent.get(entry.id)
    if (response) {
      delete element.dataset.outboxId
      element.dataset.markId = (await response.json()).id
      this.made.push(element)
    }
  }

  #pointAt(event) {
    const rect = this.pageTarget.getBoundingClientRect()
    const scale = 1000 / rect.width
    return [ round((event.clientX - rect.left) * scale), round((event.clientY - rect.top) * scale) ]
  }

  get #headers() {
    return { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content }
  }
}

function round(number) {
  return Math.round(number * 10) / 10
}
