require "ipaddr"
require "resolv"

# Faraday middleware that refuses to open a connection to a non-public address —
# private (RFC 1918 / IPv6 ULA), loopback, or link-local (which includes the
# cloud metadata endpoint 169.254.169.254). It sits closest to the adapter so it
# runs for the initial request *and* every followed redirect, closing the SSRF
# hole where a public URL 30x-redirects into the internal network.
#
# Caveat: it resolves DNS here and the adapter resolves again, so a determined
# DNS-rebinding attacker could slip through that TOCTOU window. Pinning the
# resolved address would close it; that's deliberately out of scope.
class Feed::PublicAddressGuard < Faraday::Middleware
  class BlockedAddress < Faraday::Error; end

  def on_request(env)
    host = env.url.host.to_s
    raise BlockedAddress, "request is missing a host" if host.blank?

    addresses_for(host).each do |ip|
      next if public_address?(ip)

      raise BlockedAddress, "refusing to connect to non-public address for #{host}"
    end
  end

  private

  # The literal host if it is already an IP, otherwise every address it resolves
  # to (we block if *any* of them is non-public).
  def addresses_for(host)
    [ IPAddr.new(host) ]
  rescue IPAddr::InvalidAddressError
    resolved = Resolv.getaddresses(host).filter_map do |address|
      IPAddr.new(address)
    rescue IPAddr::InvalidAddressError
      nil
    end
    raise BlockedAddress, "could not resolve #{host}" if resolved.empty?

    resolved
  end

  def public_address?(ip)
    !(ip.private? || ip.loopback? || ip.link_local?)
  end
end
