module Account::SessionsHelper
  # A friendly, best-effort device label from a raw User-Agent string. Order is
  # deliberate: Edge/Opera UAs also contain "Chrome", and Chrome's contains
  # "Safari", so the more specific brands are matched first.
  def device_label(user_agent)
    return "Unknown device" if user_agent.blank?

    browser =
      case user_agent
      when /Edg/        then "Edge"
      when /OPR|Opera/  then "Opera"
      when /Chrome/     then "Chrome"
      when /Firefox/    then "Firefox"
      when /Safari/     then "Safari"
      else "Browser"
      end

    os =
      case user_agent
      when /iPhone/             then "iPhone"
      when /iPad/               then "iPad"
      when /Android/            then "Android"
      when /Mac OS X|Macintosh/ then "macOS"
      when /Windows/            then "Windows"
      when /Linux/              then "Linux"
      end

    os ? "#{browser} on #{os}" : browser
  end
end
