// Drift — Read Later
//
// Clicking the toolbar button POSTs the active tab's URL and title to the Drift
// API, which saves it to your reading list. Configure the server URL and an API
// token on the options page (generate the token under Account → Browser
// extension in Drift).
//
// Result feedback: a badge on the icon (✓ ok, ! error, – skipped) plus a
// tooltip (hover the icon) and a service-worker console line explaining any
// failure — open it from chrome://extensions → this extension → "service worker".

const ENDPOINT_PATH = "/api/saved_items";

chrome.action.onClicked.addListener(async (tab) => {
  if (!tab || !tab.url || !/^https?:/i.test(tab.url)) {
    return flash(tab && tab.id, "–", "#78716c", "Drift: this page can't be saved");
  }

  const { baseUrl, token } = await chrome.storage.sync.get(["baseUrl", "token"]);
  if (!baseUrl || !token) {
    chrome.runtime.openOptionsPage();
    return;
  }

  try {
    const res = await fetch(baseUrl.replace(/\/+$/, "") + ENDPOINT_PATH, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token
      },
      body: JSON.stringify({ url: tab.url, title: tab.title })
    });

    if (res.ok) {
      flash(tab.id, "✓", "#15803d", "Saved to Drift");
      return;
    }

    // Non-2xx: surface why. 401 almost always means the configured token is
    // wrong or was revoked — regenerate one in Drift and re-enter it in Options.
    const body = await res.text().catch(() => "");
    console.error(`[Drift] save failed: HTTP ${res.status}`, body);
    const reason = res.status === 401
      ? "token rejected — regenerate it in Drift and update Options"
      : `server returned HTTP ${res.status}`;
    flash(tab.id, "!", "#b91c1c", `Drift: ${reason}`);
  } catch (e) {
    // Thrown before/without a response: bad Server URL, server down, or the
    // host permission for that server was never granted.
    console.error("[Drift] request failed:", e);
    flash(tab.id, "!", "#b91c1c", `Drift: ${e.message || "request failed"} — check Server URL & permission`);
  }
});

function flash(tabId, text, color, title) {
  chrome.action.setBadgeBackgroundColor({ color });
  chrome.action.setBadgeText({ text, tabId });
  if (title) chrome.action.setTitle({ title, tabId });
  if (tabId) {
    setTimeout(() => {
      chrome.action.setBadgeText({ text: "", tabId });
      chrome.action.setTitle({ title: "Save to Drift", tabId });
    }, 3000);
  }
}
