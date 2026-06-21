class PagesController < ApplicationController
  allow_unauthenticated_access only: [ :about, :terms, :privacy, :robots, :sitemap ]
  layout "legal"

  def about
  end

  def terms
  end

  def privacy
  end

  # robots.txt and sitemap.xml are rendered dynamically so their absolute URLs
  # track the request host — correct on any self-hosted domain (see APP_HOST).
  def robots
    render layout: false, content_type: "text/plain"
  end

  def sitemap
    render layout: false, content_type: "application/xml"
  end
end
