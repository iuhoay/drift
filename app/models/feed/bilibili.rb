require "digest/md5"
require "json"
require "erb"

# Synthesizes a feed from a Bilibili user's space (space.bilibili.com/<uid>),
# which publishes no RSS of its own. We call the same JSON API the website uses
# and shape each uploaded video into a Feedjira-compatible item, so
# Feed::Refresher can upsert it through the exact same path as a real feed —
# this returns an object that quacks like a parsed feed (#title/#url/#entries).
#
# Bilibili gates the video-list API behind "WBI" request signing: a key pair
# fetched from /nav, permuted through a fixed table into a "mixin key", then
# folded into an md5 of the sorted, timestamped query. We replicate that here.
# It is a moving target — when Bilibili rotates the scheme this stops returning
# entries or raises Error, which Refresher records as a normal fetch failure.
#
# Works anonymously (a buvid cookie + synthetic fingerprint params, see
# DM_PARAMS), but that path intermittently trips risk control (-352). Set
# BILIBILI_SESSDATA to send a logged-in cookie, which is the reliable path.
#
# Intended for personal, low-volume use: it relies on undocumented endpoints
# and replicates Bilibili's anti-bot measures, which likely conflicts with
# Bilibili's terms of use. See docs/bilibili-feeds.md.
class Feed::Bilibili
  class Error < StandardError; end

  HOST = "space.bilibili.com"
  API = "https://api.bilibili.com"

  # The API rejects drift's default User-Agent and wants a bilibili.com Referer.
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Referer" => "https://www.bilibili.com/"
  }.freeze

  # Fixed permutation applied to (img_key + sub_key) to derive the mixin key.
  MIXIN_KEY_ENC_TAB = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
  ].freeze

  PAGE_SIZE = 30

  Parsed = Data.define(:title, :url, :description, :entries)
  Item   = Data.define(:entry_id, :url, :title, :author, :summary, :content, :published, :updated)

  def self.handles?(url)
    uid_from(url).present?
  end

  def self.uid_from(url)
    url.to_s[%r{//#{Regexp.escape(HOST)}/(\d+)}, 1]
  end

  def self.canonical_url(uid)
    "https://#{HOST}/#{uid}"
  end

  # Whether Bilibili spaces may be subscribed. This scrapes undocumented
  # endpoints and circumvents anti-bot measures (see the class doc), so it is
  # OFF by default in production and ON elsewhere. Override with
  # BILIBILI_FEEDS_ENABLED. Gates discovery only; feeds already created keep
  # refreshing.
  def self.enabled?
    setting = Rails.app.creds.option(:bilibili_feeds_enabled, default: nil)
    return !Rails.env.production? if setting.nil?

    ActiveModel::Type::Boolean.new.cast(setting)
  end

  def self.fetch(feed, http)
    new(feed, http).fetch
  end

  # Optional Bilibili login cookie. Set BILIBILI_SESSDATA in the environment
  # (.env in dev) or add bilibili_sessdata to credentials in production.
  def self.sessdata
    Rails.app.creds.option(:bilibili_sessdata, default: nil).presence
  end

  def initialize(feed, http, sessdata: self.class.sessdata)
    @http = http
    @sessdata = sessdata
    @uid = self.class.uid_from(feed.feed_url)
    raise Error, "not a Bilibili space URL: #{feed.feed_url}" if @uid.blank?
  end

  def fetch
    prime_session
    videos = search_videos
    author = videos.first&.dig("author")

    Parsed.new(
      title: author.present? ? "#{author} · 哔哩哔哩" : "Bilibili UID #{@uid}",
      url: self.class.canonical_url(@uid),
      description: nil,
      entries: videos.map { |video| item_for(video) }
    )
  end

  private

  def item_for(video)
    bvid = video["bvid"].to_s
    description = video["description"].to_s

    Item.new(
      entry_id: bvid,
      url: "https://www.bilibili.com/video/#{bvid}",
      title: video["title"].to_s,
      author: video["author"].to_s,
      summary: description,
      # Just the description: the entry view embeds the player (which shows the
      # cover as its poster), so a static cover image here would only duplicate.
      content: description.present? ? "<p>#{ERB::Util.html_escape(description)}</p>" : nil,
      published: (Time.at(video["created"].to_i) if video["created"]),
      updated: nil
    )
  end

  # Risk control (-352) also inspects these device-fingerprint params, which
  # the real web player computes from the browser's WebGL context and folds
  # into the signed query. Bilibili currently only checks they are present and
  # well-formed (not that they match a live device), so plausible static values
  # alongside the buvid cookie clear it for anonymous callers — until Bilibili
  # starts validating them, at which point this trips -352 again.
  #
  # These are NOT captured from a real browser; they are synthetic values
  # composed from the public bilibili-API-collect docs, decoding to:
  #   dm_img_str       => "WebGL 1.0 (OpenGL ES 2.0 Chromium)"   (WebGL VERSION)
  #   dm_cover_img_str => "ANGLE (Apple, Apple M1, OpenGL 4.1 Metal - 89.3)..."
  #                       (WebGL RENDERER + VENDOR — a GPU fingerprint)
  #   dm_img_list      => "[]"   (recorded pointer events: none)
  #   dm_img_inter     => zeroed interaction metadata (dwell / window / offset)
  DM_PARAMS = {
    dm_img_list: "[]",
    dm_img_str: "V2ViR0wgMS4wIChPcGVuR0wgRVMgMi4wIENocm9taXVtKQ",
    dm_cover_img_str: "QU5HTEUgKEFwcGxlLCBBcHBsZSBNMSwgT3BlbkdMIDQuMSBNZXRhbCAtIDg5LjMpR29vZ2xlIEluYy4gKEFwcGxlKQ",
    dm_img_inter: '{"ds":[],"wh":[0,0,0],"of":[0,0,0]}'
  }.freeze

  def search_videos
    params = { mid: @uid, ps: PAGE_SIZE, pn: 1, order: "pubdate", platform: "web" }.merge(DM_PARAMS)
    body = get_json("/x/space/wbi/arc/search", sign(params))
    body.dig("data", "list", "vlist") || []
  end

  # Builds the Cookie header for the API calls. SESSDATA (a logged-in session,
  # optional) is the reliable way past risk control (-352) and always goes out
  # when configured. A buvid is the best-effort anonymous fallback; if priming
  # it fails we still send whatever SESSDATA we have.
  def prime_session
    parts = [ cookie("SESSDATA", @sessdata) ]
    begin
      spi = get_json("/x/frontend/finger/spi")
      parts << cookie("buvid3", spi.dig("data", "b_3"))
      parts << cookie("buvid4", spi.dig("data", "b_4"))
    rescue Error
      # buvid priming is best-effort; SESSDATA (if set) still goes out alone.
    end
    @cookie = parts.compact.join("; ").presence
  end

  def cookie(name, value)
    "#{name}=#{value}" if value.present?
  end

  # --- WBI signing ---------------------------------------------------------

  def sign(params)
    signed = params.merge(wts: Time.now.to_i)
    query = URI.encode_www_form(signed.sort_by { |k, _| k.to_s })
    signed.merge(w_rid: Digest::MD5.hexdigest(query + mixin_key))
  end

  def mixin_key
    @mixin_key ||= begin
      img = nav_keys.dig("wbi_img", "img_url")
      sub = nav_keys.dig("wbi_img", "sub_url")
      raw = "#{key_from(img)}#{key_from(sub)}"
      MIXIN_KEY_ENC_TAB.map { |i| raw[i] }.join[0, 32]
    end
  end

  # nav reports code -101 ("not logged in") for anonymous callers but still
  # ships the public WBI keys, so we read its data regardless of the code.
  def nav_keys
    @nav_keys ||= get_json("/x/web-interface/nav", check_code: false)["data"] || {}
  end

  def key_from(image_url)
    File.basename(image_url.to_s, ".*")
  end

  # --- HTTP ----------------------------------------------------------------

  def get_json(path, params = {}, check_code: true)
    response = @http.get("#{API}#{path}") do |req|
      HEADERS.each { |key, value| req.headers[key] = value }
      req.headers["Cookie"] = @cookie if @cookie
      req.params.update(params.transform_keys(&:to_s)) if params.any?
    end
    raise Error, "Bilibili HTTP #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    code = body["code"].to_i
    raise Error, "Bilibili API code #{code}: #{body['message']}" if check_code && !code.zero?

    body
  rescue JSON::ParserError => e
    raise Error, "Bilibili returned non-JSON: #{e.message}"
  end
end
