json.subscription do
  json.partial! "api/subscriptions/subscription", subscription: @subscription
end
