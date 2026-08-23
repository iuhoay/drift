import { Controller } from "@hotwired/stimulus"

// The app shell scrolls this <main>, not the document. After a stream,
// pin the window back to 0 (morph/focus can scrollIntoView the <html>
// and leave a gap under the h-dvh chrome) and clamp this box to its
// new max so a shorter list cannot overscroll.
export default class extends Controller {
  connect() {
    this.preserve = this.preserve.bind(this)
    document.addEventListener("turbo:before-stream-render", this.preserve)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.preserve)
  }

  preserve(event) {
    const top = this.element.scrollTop
    const left = this.element.scrollLeft
    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await render(streamElement)
      window.scrollTo(0, 0)
      document.documentElement.scrollTop = 0
      document.body.scrollTop = 0
      const max = Math.max(0, this.element.scrollHeight - this.element.clientHeight)
      this.element.scrollTop = Math.min(top, max)
      this.element.scrollLeft = left
    }
  }
}
