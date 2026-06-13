import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

// Marks the open entry as read once its page actually renders. request.js posts
// in the background (via Turbo.fetch, not Turbo Drive) so it doesn't drive the
// navigation progress bar, handles the CSRF token + turbo-stream Accept header,
// and auto-renders the returned stream that flips the read/unread button.
//
// EntriesController#show stays a safe GET: Turbo's hover prefetch fetches the
// page but never connects Stimulus, so the entry is only marked read on a real
// visit. mark_read! is idempotent, so a re-fire on cache restore is harmless.
export default class extends Controller {
  static values = { url: String }

  connect() {
    post(this.urlValue, { responseKind: "turbo-stream" })
  }
}
