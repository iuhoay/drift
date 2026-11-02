import { Controller } from "@hotwired/stimulus"

// Landing tagline: each word starts muted and comes up in reading order as it
// crosses a line in the viewport. One shot. Reduced motion leaves the type
// at full strength, and so does a visit with no JavaScript.
export default class extends Controller {
  static targets = [ "word" ]

  connect() {
    this.timers = []
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.element.classList.add("is-armed")
    this.seen = 0
    this.observer = new IntersectionObserver((entries) => this.reveal(entries), {
      root: null,
      rootMargin: "0px 0px -28% 0px",
      threshold: 0.6
    })
    this.wordTargets.forEach((word) => this.observer.observe(word))
  }

  disconnect() {
    this.observer?.disconnect()
    this.timers.forEach((id) => window.clearTimeout(id))
  }

  reveal(entries) {
    const words = this.wordTargets
    entries
      .filter((entry) => entry.isIntersecting)
      .sort((a, b) => words.indexOf(a.target) - words.indexOf(b.target))
      .forEach((entry) => {
        const delay = this.seen * 60
        this.seen += 1
        this.observer.unobserve(entry.target)
        this.timers.push(window.setTimeout(() => entry.target.classList.add("is-on"), delay))
      })
  }
}
