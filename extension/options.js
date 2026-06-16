const $ = (id) => document.getElementById(id);

function setStatus(message, kind) {
  const el = $("status");
  el.textContent = message;
  el.className = kind || "";
}

async function load() {
  const { baseUrl, token } = await chrome.storage.sync.get(["baseUrl", "token"]);
  if (baseUrl) $("baseUrl").value = baseUrl;
  if (token) $("token").value = token;
}

// "https://drift.example.com/foo" -> "https://drift.example.com/*", the pattern
// the service worker needs host permission for to POST without a CORS block.
function originPattern(rawUrl) {
  const u = new URL(rawUrl);
  return `${u.protocol}//${u.host}/*`;
}

async function save() {
  const baseUrl = $("baseUrl").value.trim().replace(/\/+$/, "");
  const token = $("token").value.trim();

  if (!baseUrl || !token) {
    return setStatus("Both the server URL and a token are required.", "err");
  }

  let pattern;
  try {
    pattern = originPattern(baseUrl);
  } catch (_e) {
    return setStatus("That doesn't look like a valid URL.", "err");
  }

  const granted = await chrome.permissions.request({ origins: [pattern] });
  if (!granted) {
    return setStatus("Permission to reach that server was declined.", "err");
  }

  await chrome.storage.sync.set({ baseUrl, token });
  setStatus("Saved. Click the toolbar icon on any page to save it.", "ok");
}

document.addEventListener("DOMContentLoaded", load);
$("save").addEventListener("click", save);
