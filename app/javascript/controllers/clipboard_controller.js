import { Controller } from "@hotwired/stimulus"

// One-click copy of a prompt sitting in a hidden textarea. The clipboard API
// needs a secure context; the fallback covers http dev hosts.
export default class extends Controller {
  static targets = [ "source", "button" ]

  disconnect() {
    clearTimeout(this.timer)
  }

  copy() {
    const button = this.buttonTarget
    const label = button.textContent

    this.write(this.sourceTarget.value).then(() => {
      this.flash(button, label, "[copied]")
    }).catch(() => {
      this.flash(button, label, "[failed]")
    })
  }

  flash(button, label, message) {
    button.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      button.textContent = label
    }, 1500)
  }

  write(text) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(text).catch(() => this.writeFallback(text))
    }

    return this.writeFallback(text)
  }

  writeFallback(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "fixed"
    area.style.left = "-9999px"
    document.body.appendChild(area)
    area.select()
    const ok = document.execCommand("copy")
    area.remove()

    return ok ? Promise.resolve() : Promise.reject(new Error("copy failed"))
  }
}
