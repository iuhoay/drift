// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Register the service worker in production only; in development a cached
// service worker tends to serve stale pages and obscure code changes.
const railsEnv = document.querySelector('meta[name="rails-env"]')?.content
if (railsEnv === "production" && "serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker")
}
