class HomeController < ApplicationController
  allow_unauthenticated_access only: :index
  layout "landing"

  # The front door. Signed-out visitors get the marketing landing page; signed-in
  # readers are sent to their inbox (the canonical reader home the nav points at).
  def index
    redirect_to entries_path if authenticated?
  end
end
