# Bilibili feeds

Pasting a `space.bilibili.com/<uid>` address subscribes to that user's video
uploads. Bilibili serves no RSS for a space, so Drift synthesizes one from the
public video list and embeds Bilibili's official player on each entry.

> [!CAUTION]
> **This integration is intended for personal, low-volume use.** It reads
> Bilibili through undocumented, browser-only endpoints, which very likely
> conflicts with Bilibili's [用户使用协议](https://www.bilibili.com/protocal/licence.html)
> and can break whenever Bilibili changes them. Do **not** run it as a public,
> high-traffic, or commercial service.

For that reason it is **off by default in production** and on elsewhere. Set
`BILIBILI_FEEDS_ENABLED=true` to allow subscribing a Bilibili space on an
instance; when off, a `space.bilibili.com` address simply resolves to no feed.
The gate only guards new subscriptions — feeds already created keep refreshing.

The default anonymous path is occasionally rejected by Bilibili. For a more
reliable path, set `BILIBILI_SESSDATA` to a logged-in session cookie — but use
**your own** account, which may be rate-limited or banned for automated use.
Leave it unset to stay on the best-effort anonymous path.
