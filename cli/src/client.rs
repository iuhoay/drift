use serde::{Deserialize, Serialize};
use std::time::Duration;

const TIMEOUT_SECS: u64 = 15;
const BODY_SNIPPET: usize = 200;

#[derive(Debug, Clone, Default)]
pub struct EntriesQuery<'a> {
    pub scope: Option<&'a str>,
    pub feed_id: Option<i64>,
    pub q: Option<&'a str>,
    pub limit: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubscriptionsResponse {
    pub subscriptions: Vec<Subscription>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Subscription {
    pub id: i64,
    pub feed_id: i64,
    pub title: String,
    pub feed_url: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntriesResponse {
    pub entries: Vec<EntrySummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntrySummary {
    pub id: i64,
    #[serde(default)]
    pub title: Option<String>,
    pub url: String,
    #[serde(default)]
    pub published_at: Option<String>,
    #[serde(default)]
    pub excerpt: Option<String>,
    pub read: bool,
    pub starred: bool,
    pub feed: FeedRef,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EntryDetail {
    pub id: i64,
    #[serde(default)]
    pub title: Option<String>,
    pub url: String,
    #[serde(default)]
    pub author: Option<String>,
    #[serde(default)]
    pub published_at: Option<String>,
    pub read: bool,
    pub starred: bool,
    pub has_full_content: bool,
    #[serde(default)]
    pub body: Option<String>,
    pub feed: FeedRef,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeedRef {
    pub id: i64,
    pub title: String,
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    token: String,
}

#[derive(Debug)]
pub enum Error {
    Unauthorized,
    NotFound,
    Http { status: u16, body: String },
    Network(String),
    Parse(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unauthorized => write!(f, "unauthorized — run `drift auth login`"),
            Self::NotFound => write!(f, "entry not found (or not subscribed)"),
            Self::Http { status, body } if body.is_empty() => write!(f, "HTTP {status}"),
            Self::Http { status, body } => write!(f, "HTTP {status}: {body}"),
            Self::Network(msg) | Self::Parse(msg) => write!(f, "{msg}"),
        }
    }
}

impl std::error::Error for Error {}

pub fn normalize_host(host: &str) -> String {
    crate::config::normalize_host(host)
}

pub fn subscriptions_url(host: &str) -> String {
    format!("{}/api/subscriptions", normalize_host(host))
}

pub fn token_url(host: &str) -> String {
    format!("{}/api/cli/token", normalize_host(host))
}

pub fn authorize_url(host: &str, redirect_uri: &str, state: &str) -> String {
    format!(
        "{}/cli/authorizations/new?redirect_uri={}&state={}",
        normalize_host(host),
        percent_encode(redirect_uri),
        percent_encode(state)
    )
}

pub fn entry_url(host: &str, id: i64) -> String {
    format!("{}/api/entries/{id}", normalize_host(host))
}

pub fn entries_url(host: &str, query: &EntriesQuery<'_>) -> String {
    let mut url = format!("{}/api/entries", normalize_host(host));
    let mut pairs: Vec<(&str, String)> = Vec::new();

    if let Some(scope) = query.scope {
        pairs.push(("scope", scope.to_string()));
    }
    if let Some(feed_id) = query.feed_id {
        pairs.push(("feed_id", feed_id.to_string()));
    }
    if let Some(q) = query.q.filter(|value| !value.is_empty()) {
        pairs.push(("q", q.to_string()));
    }
    if let Some(limit) = query.limit {
        pairs.push(("limit", limit.to_string()));
    }

    if !pairs.is_empty() {
        url.push('?');
        url.push_str(
            &pairs
                .into_iter()
                .map(|(key, value)| format!("{key}={}", percent_encode(&value)))
                .collect::<Vec<_>>()
                .join("&"),
        );
    }
    url
}

fn percent_encode(value: &str) -> String {
    let mut out = String::new();
    for byte in value.as_bytes() {
        match *byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*byte as char);
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

fn snippet(body: &str) -> String {
    let collapsed = body.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = collapsed.chars();
    let taken: String = chars.by_ref().take(BODY_SNIPPET).collect();
    if chars.next().is_some() {
        format!("{taken}…")
    } else {
        taken
    }
}

pub struct Client {
    agent: ureq::Agent,
    host: String,
    token: String,
}

impl Client {
    pub fn new(host: impl Into<String>, token: impl Into<String>) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(TIMEOUT_SECS))
            .user_agent(concat!("drift-cli/", env!("CARGO_PKG_VERSION")))
            .build();
        Self {
            agent,
            host: normalize_host(&host.into()),
            token: token.into(),
        }
    }

    pub fn subscriptions(&self) -> Result<SubscriptionsResponse, Error> {
        self.get_json(&subscriptions_url(&self.host), false)
    }

    pub fn entries(&self, query: &EntriesQuery<'_>) -> Result<EntriesResponse, Error> {
        self.get_json(&entries_url(&self.host, query), false)
    }

    pub fn entry(&self, id: i64) -> Result<EntryDetail, Error> {
        self.get_json(&entry_url(&self.host, id), true)
    }

    pub fn exchange_code(host: &str, code: &str) -> Result<String, Error> {
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(TIMEOUT_SECS))
            .user_agent(concat!("drift-cli/", env!("CARGO_PKG_VERSION")))
            .build();

        let response = agent
            .post(&token_url(host))
            .set("Accept", "application/json")
            .send_json(serde_json::json!({ "code": code }));

        match response {
            Ok(response) => {
                let body: TokenResponse = response.into_json().map_err(|err| {
                    Error::Parse(format!("failed to parse token response: {err}"))
                })?;
                if body.token.is_empty() {
                    Err(Error::Parse("token response was empty".into()))
                } else {
                    Ok(body.token)
                }
            }
            Err(ureq::Error::Status(status, response)) => {
                let body = response.into_string().unwrap_or_default();
                Err(map_status(status, body, false))
            }
            Err(ureq::Error::Transport(err)) => {
                Err(Error::Network(format!("request failed: {err}")))
            }
        }
    }

    fn get_json<T>(&self, url: &str, not_found_is_entry: bool) -> Result<T, Error>
    where
        T: for<'de> Deserialize<'de>,
    {
        let response = self
            .agent
            .get(url)
            .set("Authorization", &format!("Bearer {}", self.token))
            .set("Accept", "application/json")
            .call();

        match response {
            Ok(response) => response
                .into_json()
                .map_err(|err| Error::Parse(format!("failed to parse response: {err}"))),
            Err(ureq::Error::Status(status, response)) => {
                let body = response.into_string().unwrap_or_default();
                Err(map_status(status, body, not_found_is_entry))
            }
            Err(ureq::Error::Transport(err)) => {
                Err(Error::Network(format!("request failed: {err}")))
            }
        }
    }
}

fn map_status(status: u16, body: String, not_found_is_entry: bool) -> Error {
    match status {
        401 => Error::Unauthorized,
        404 if not_found_is_entry => Error::NotFound,
        _ => Error::Http {
            status,
            body: snippet(&body),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_trailing_slash_from_host() {
        assert_eq!(
            token_url("https://rdrift.app/"),
            "https://rdrift.app/api/cli/token"
        );
        assert_eq!(
            authorize_url(
                "https://rdrift.app/",
                "http://127.0.0.1:9/callback",
                "abc_def-12"
            ),
            "https://rdrift.app/cli/authorizations/new?redirect_uri=http%3A%2F%2F127.0.0.1%3A9%2Fcallback&state=abc_def-12"
        );
        assert_eq!(
            subscriptions_url("https://rdrift.app/"),
            "https://rdrift.app/api/subscriptions"
        );
        assert_eq!(
            entry_url("https://rdrift.app/", 42),
            "https://rdrift.app/api/entries/42"
        );
    }

    #[test]
    fn entries_url_omits_empty_params() {
        assert_eq!(
            entries_url("https://rdrift.app", &EntriesQuery::default()),
            "https://rdrift.app/api/entries"
        );
    }

    #[test]
    fn entries_url_includes_stable_query_order() {
        let url = entries_url(
            "https://rdrift.app/",
            &EntriesQuery {
                scope: Some("unread"),
                feed_id: Some(2),
                q: Some("hello world"),
                limit: Some(20),
            },
        );
        assert_eq!(
            url,
            "https://rdrift.app/api/entries?scope=unread&feed_id=2&q=hello%20world&limit=20"
        );
    }

    #[test]
    fn entries_url_encodes_cjk_query() {
        let url = entries_url(
            "https://rdrift.app",
            &EntriesQuery {
                q: Some("中"),
                ..EntriesQuery::default()
            },
        );
        assert_eq!(url, "https://rdrift.app/api/entries?q=%E4%B8%AD");
    }

    #[test]
    fn optional_entry_fields_default() {
        let entry: EntryDetail = serde_json::from_str(
            r#"{
                "id": 1,
                "url": "https://example.com/posts/1",
                "read": false,
                "starred": true,
                "has_full_content": false,
                "feed": { "id": 2, "title": "Example" }
            }"#,
        )
        .unwrap();
        assert_eq!(entry.title, None);
        assert_eq!(entry.author, None);
        assert_eq!(entry.published_at, None);
        assert_eq!(entry.body, None);
    }
}
