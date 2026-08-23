import { Controller } from "@hotwired/stimulus"

// Pick an existing category or type a new one. The manage page autosaves
// on pick/clear; typing still saves via the form's onchange (blur). The
// new-feed form only fills the field — chips are shortcuts, not submits.
export default class extends Controller {
  static targets = [ "input", "list", "option", "chip", "clear" ]
  static values = { autosubmit: Boolean }

  connect() {
    this.inputTarget.removeAttribute("list")
    this.originalValue = this.inputTarget.value
    this.index = -1
    this.sync()
  }

  open() {
    if (!this.hasListTarget) return

    this.originalValue = this.inputTarget.value
    this.filter()
    this.highlight(this.currentIndex())
  }

  close() {
    if (!this.hasListTarget) return

    this.listTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.index = -1
    this.optionTargets.forEach((option) => option.removeAttribute("aria-selected"))
  }

  filter() {
    this.sync()
    if (!this.hasListTarget) return

    const query = this.inputTarget.value.trim().toLowerCase()
    let any = false

    this.optionTargets.forEach((option) => {
      const match = option.dataset.value.toLowerCase().includes(query)
      option.hidden = !match
      if (match) any = true
    })

    this.listTarget.hidden = !any
    this.inputTarget.setAttribute("aria-expanded", any ? "true" : "false")
    this.highlight(-1)
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.inputTarget.value = this.originalValue
      this.sync()
      this.close()
      return
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      if (this.hasListTarget && this.listTarget.hidden) this.open()
      this.move(event.key === "ArrowDown" ? 1 : -1)
      return
    }

    if (event.key === "Enter" && this.index >= 0 && this.hasListTarget && !this.listTarget.hidden) {
      event.preventDefault()
      this.apply(this.optionTargets[this.index].dataset.value)
    }
  }

  pick(event) {
    event.preventDefault()
    this.apply(event.currentTarget.dataset.value)
  }

  clear(event) {
    event.preventDefault()
    this.apply("")
  }

  apply(value) {
    if (!this.autosubmitValue && this.inputTarget.value === value) value = ""

    const previous = this.originalValue ?? this.inputTarget.value
    this.inputTarget.value = value
    this.sync()
    this.close()

    if (this.autosubmitValue && value !== previous) this.inputTarget.form.requestSubmit()
  }

  sync() {
    const current = this.inputTarget.value.trim().toLowerCase()

    this.chipTargets.forEach((chip) => {
      chip.classList.toggle("term-btn-on", chip.dataset.value.toLowerCase() === current)
    })

    if (this.hasClearTarget) this.clearTarget.hidden = this.inputTarget.value.trim() === ""
  }

  currentIndex() {
    const current = this.inputTarget.value.trim().toLowerCase()
    return this.optionTargets.findIndex((option) => option.dataset.value.toLowerCase() === current)
  }

  move(step) {
    const visible = this.optionTargets
      .map((option, i) => [ option, i ])
      .filter(([ option ]) => !option.hidden)
    if (visible.length === 0) return

    const current = visible.findIndex(([ , i ]) => i === this.index)
    const next = current === -1
      ? (step > 0 ? visible[0] : visible[visible.length - 1])
      : visible[(current + step + visible.length) % visible.length]

    this.highlight(next[1])
    next[0].scrollIntoView({ block: "nearest" })
  }

  highlight(index) {
    this.index = index
    this.optionTargets.forEach((option, i) => {
      option.setAttribute("aria-selected", i === index ? "true" : "false")
    })

    const active = index >= 0 ? this.optionTargets[index] : null
    if (active?.id) this.inputTarget.setAttribute("aria-activedescendant", active.id)
    else this.inputTarget.removeAttribute("aria-activedescendant")
  }
}
