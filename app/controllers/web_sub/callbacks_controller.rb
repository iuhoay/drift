# Receives WebSub (PubSubHubbub) traffic for a single subscription, addressed by an
# unguessable per-subscription token in the URL (so feed ids aren't exposed).
#
# The hub is an anonymous, non-browser client, so this controller inherits
# ActionController::Base directly — sidestepping ApplicationController's auth
# (:require_authentication) and `allow_browser versions: :modern` gates — and disables
# forgery protection, which would otherwise reject the hub's token-less POST.
class WebSub::CallbacksController < ActionController::Base
  skip_forgery_protection

  # Push payloads are tiny (a YouTube notification is a few KB); refuse anything
  # implausibly large before reading it into memory.
  MAX_BODY_BYTES = 2.megabytes

  # GET: the hub confirms a subscribe/unsubscribe by calling us back with the
  # challenge it wants echoed. We only confirm intents we actually issued — the
  # token must resolve and the topic must match the subscription's feed.
  def verify
    subscription = WebSubSubscription.find_by(callback_token: params[:token])
    mode = params["hub.mode"]

    unless subscription && %w[subscribe unsubscribe].include?(mode) &&
           params["hub.topic"] == subscription.topic_url
      return head :not_found
    end

    if mode == "subscribe"
      subscription.confirm_subscription!(params["hub.lease_seconds"])
    else
      subscription.confirm_unsubscription!
    end

    render plain: params["hub.challenge"].to_s
  end

  # POST: a content delivery. Read the raw body first (it's what the HMAC is over,
  # and nothing in the stack parses application/atom+xml into params), verify the
  # signature, then ingest. A missing/invalid signature is dropped with a 404 so we
  # neither ingest unverified content nor confirm the endpoint exists.
  def receive
    return head :payload_too_large if request.content_length.to_i > MAX_BODY_BYTES

    body = request.raw_post
    subscription = WebSubSubscription.find_by(callback_token: params[:token])

    unless subscription&.valid_signature?(body, request.headers["X-Hub-Signature"])
      return head :not_found
    end

    Feed::Refresher.ingest(subscription.feed, body)
    subscription.record_delivery!
    head :no_content
  end
end
