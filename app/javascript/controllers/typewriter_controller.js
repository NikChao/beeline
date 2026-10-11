import { Controller } from "@hotwired/stimulus"
import { Lexical } from "lexxy"

const {
  COMMAND_PRIORITY_CRITICAL, FORMAT_TEXT_COMMAND,
  KEY_BACKSPACE_COMMAND, KEY_DELETE_COMMAND, DELETE_CHARACTER_COMMAND, DELETE_WORD_COMMAND, DELETE_LINE_COMMAND,
  REMOVE_TEXT_COMMAND, CUT_COMMAND, UNDO_COMMAND, REDO_COMMAND,
  CONTROLLED_TEXT_INSERTION_COMMAND, INSERT_PARAGRAPH_COMMAND, INSERT_LINE_BREAK_COMMAND, PASTE_COMMAND, DROP_COMMAND,
  $getSelection, $isRangeSelection, $createParagraphNode, $createTextNode
} = Lexical

// Anything that would take letters off the page.
const ERASING_COMMANDS = [
  KEY_BACKSPACE_COMMAND, KEY_DELETE_COMMAND, DELETE_CHARACTER_COMMAND, DELETE_WORD_COMMAND, DELETE_LINE_COMMAND,
  REMOVE_TEXT_COMMAND, CUT_COMMAND, UNDO_COMMAND, REDO_COMMAND
]

// Harmless with a caret, but they replace the text when a selection is active.
const OVERWRITING_COMMANDS = [
  CONTROLLED_TEXT_INSERTION_COMMAND, INSERT_PARAGRAPH_COMMAND, INSERT_LINE_BREAK_COMMAND, PASTE_COMMAND, DROP_COMMAND
]

const COMPOSING_INPUTS = [ "deleteCompositionText", "insertCompositionText", "insertFromComposition" ]
const HOTKEY_FORMATS = { b: "bold", i: "italic", u: "underline" }
const UNSUPPORTED_FORMATS = [ "code", "strikethrough", "highlight", "subscript", "superscript" ]

export default class extends Controller {
  static targets = [ "editor" ]

  connect() {
    if (this.editorTarget.editor) {
      this.#prepare()
    } else {
      this.editorTarget.addEventListener("lexxy:initialize", () => this.#prepare(), { once: true })
    }
  }

  disconnect() {
    this.unregister?.forEach(unregister => unregister())
  }

  // Keys

  press(event) {
    const key = event.key.toLowerCase()
    const shortcut = event.metaKey || event.ctrlKey

    if (key === "backspace" || key === "delete" || (shortcut && [ "x", "y", "z" ].includes(key))) {
      this.#refuse(event)
    } else if (event.ctrlKey && !event.metaKey && !event.altKey && !event.shiftKey && HOTKEY_FORMATS[key]) {
      // Ctrl+B/I/U everywhere, including macOS where Lexical only listens for ⌘.
      event.preventDefault()
      event.stopPropagation()
      this.editorTarget.editor.dispatchCommand(FORMAT_TEXT_COMMAND, HOTKEY_FORMATS[key])
    }
  }

  input(event) {
    if (COMPOSING_INPUTS.includes(event.inputType)) return

    const erasing = event.inputType.startsWith("delete") || event.inputType.startsWith("history") || event.inputType === "insertReplacementText"
    const overwriting = event.inputType.startsWith("insert") && !window.getSelection().isCollapsed

    if (erasing || overwriting) this.#refuse(event)
  }

  refuse(event) {
    this.#refuse(event)
  }

  typed() {
    this.dirty = true
    this.element.classList.add("typewriter--typing")
    this.#keepCaretLevel()
  }

  rest() {
    this.element.classList.remove("typewriter--typing")
  }

  // Fields

  next(event) {
    event.preventDefault()
    const fields = [ ...this.element.querySelectorAll("input[type=text]") ]
    const following = fields[fields.indexOf(event.target) + 1]

    following ? following.focus() : this.editorTarget.focus()
  }

  submit() {
    this.dirty = false
  }

  confirmLeaving(event) {
    if (!this.dirty) return

    const message = "Leave this page? What you typed hasn't been saved."
    if (event.type === "beforeunload") {
      event.preventDefault()
    } else if (!confirm(message)) {
      event.preventDefault()
    }
  }

  // Private

  #prepare() {
    const editor = this.editorTarget.editor

    this.unregister = [
      ...ERASING_COMMANDS.map(command => editor.registerCommand(command, event => {
        event?.preventDefault?.()
        return true
      }, COMMAND_PRIORITY_CRITICAL)),

      ...OVERWRITING_COMMANDS.map(command => editor.registerCommand(command, event => {
        const selection = $getSelection()
        if (!$isRangeSelection(selection) || selection.isCollapsed()) return false

        event?.preventDefault?.()
        return true
      }, COMMAND_PRIORITY_CRITICAL)),

      ...this.#keepToSimpleMarkdown(editor)
    ]
  }

  // Lexxy's markdown shortcuts cover everything; on a typewriter we only want
  // headings, bullets and bold/italic/underline. Fold the rest back into prose.
  #keepToSimpleMarkdown(editor) {
    const unwrap = node => {
      node.getChildren().forEach(child => node.insertBefore(child))
      node.remove()
    }

    const transforms = {
      quote: node => { node.replace($createParagraphNode(), true) },
      code: node => { node.replace($createParagraphNode().append($createTextNode(node.getTextContent()))) },
      list: node => { if (node.getListType() !== "bullet") node.setListType("bullet") },
      link: unwrap,
      autolink: unwrap,
      horizontal_divider: node => { node.remove() },
      text: node => {
        UNSUPPORTED_FORMATS.forEach(format => { if (node.hasFormat(format)) node.toggleFormat(format) })
        if (node.getStyle()) node.setStyle("")
      }
    }

    return Object.entries(transforms)
      .filter(([ type ]) => editor._nodes.has(type))
      .map(([ type, transform ]) => editor.registerNodeTransform(editor._nodes.get(type).klass, transform))
  }

  #refuse(event) {
    event.preventDefault()
    event.stopImmediatePropagation()

    this.element.classList.remove("typewriter--refused")
    void this.element.offsetWidth
    this.element.classList.add("typewriter--refused")
  }

  // Like a carriage: the line you're typing stays put and the paper moves.
  #keepCaretLevel() {
    const selection = window.getSelection()
    if (!selection.rangeCount) return

    let rect = selection.getRangeAt(0).getBoundingClientRect()
    if (!rect.height) {
      const node = selection.anchorNode
      rect = (node instanceof Element ? node : node?.parentElement)?.getBoundingClientRect()
    }
    if (!rect) return

    const offset = rect.top - window.innerHeight * 0.45
    if (Math.abs(offset) > 2) window.scrollBy({ top: offset, behavior: "smooth" })
  }
}
