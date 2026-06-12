class PwaController < ApplicationController
  allow_unauthenticated_access only: :offline

  def offline
    render template: "pwa/offline", layout: false
  end
end
