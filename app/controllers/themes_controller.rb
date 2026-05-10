class ThemesController < ApplicationController
  CYCLE = { nil => "light", "light" => "dark", "dark" => "auto", "auto" => "light" }.freeze

  def update
    next_theme = CYCLE[cookies[:theme]]
    if next_theme == "auto"
      cookies.delete(:theme)
    else
      cookies.permanent[:theme] = next_theme
    end
    redirect_back_or_to root_path
  end
end
