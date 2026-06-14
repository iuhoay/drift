class PagesController < ApplicationController
  allow_unauthenticated_access only: [ :about, :terms, :privacy ]
  layout "legal"

  def about
  end

  def terms
  end

  def privacy
  end
end
