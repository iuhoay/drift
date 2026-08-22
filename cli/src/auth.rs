use crate::client;
use crate::config;
use std::io::{self, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

const LOGIN_TIMEOUT: Duration = Duration::from_secs(300);

#[derive(Debug)]
pub enum Error {
    Bind(io::Error),
    Timeout,
    Denied,
    StateMismatch,
    Io(String),
    Exchange(client::Error),
    Config(config::Error),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Bind(err) => write!(f, "failed to listen on 127.0.0.1: {err}"),
            Self::Timeout => write!(f, "timed out waiting for the browser to authorize"),
            Self::Denied => write!(f, "authorization was canceled"),
            Self::StateMismatch => write!(f, "authorization state mismatch — try again"),
            Self::Io(msg) => write!(f, "{msg}"),
            Self::Exchange(err) => write!(f, "{err}"),
            Self::Config(err) => write!(f, "{err}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<client::Error> for Error {
    fn from(err: client::Error) -> Self {
        Self::Exchange(err)
    }
}

impl From<config::Error> for Error {
    fn from(err: config::Error) -> Self {
        Self::Config(err)
    }
}

enum Callback {
    Code(String),
    Denied,
    Other,
}

pub fn login_via_browser(host: &str) -> Result<(config::Settings, std::path::PathBuf), Error> {
    let listener = TcpListener::bind("127.0.0.1:0").map_err(Error::Bind)?;
    let port = listener.local_addr().map_err(Error::Bind)?.port();
    let state = random_state()?;
    let redirect_uri = format!("http://127.0.0.1:{port}/callback");
    let url = client::authorize_url(host, &redirect_uri, &state);

    eprintln!("Opening {url}");
    eprintln!("If the browser does not open, visit that URL.");
    open_browser(&url);

    let code = wait_for_code(listener, &state)?;
    let token = client::Client::exchange_code(host, &code)?;
    let path = config::config_path();
    config::save(&path, host, &token)?;
    Ok((
        config::Settings {
            host: config::normalize_host(host),
            token: Some(token),
        },
        path,
    ))
}

fn wait_for_code(listener: TcpListener, expected_state: &str) -> Result<String, Error> {
    let expected_state = expected_state.to_string();
    let (tx, rx) = mpsc::channel();

    thread::spawn(move || {
        let _ = tx.send(accept_callback(listener, &expected_state));
    });

    match rx.recv_timeout(LOGIN_TIMEOUT) {
        Ok(result) => result,
        Err(_) => Err(Error::Timeout),
    }
}

fn accept_callback(listener: TcpListener, expected_state: &str) -> Result<String, Error> {
    loop {
        let (mut stream, _) = listener
            .accept()
            .map_err(|err| Error::Io(format!("failed to accept browser callback: {err}")))?;
        match handle_stream(&mut stream, expected_state) {
            Ok(Callback::Code(code)) => return Ok(code),
            Ok(Callback::Denied) => return Err(Error::Denied),
            Ok(Callback::Other) => continue,
            Err(err) => return Err(err),
        }
    }
}

fn handle_stream(stream: &mut TcpStream, expected_state: &str) -> Result<Callback, Error> {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));
    let request = read_http_request(stream)?;
    let Some(target) = request_target(&request) else {
        respond(stream, 400, "Bad request")?;
        return Ok(Callback::Other);
    };

    let (path, query) = split_target(target);
    if path != "/callback" {
        respond(stream, 404, "Not found")?;
        return Ok(Callback::Other);
    }

    let params = parse_query(query.unwrap_or(""));
    let state = params.iter().find(|(key, _)| key == "state").map(|(_, value)| value.as_str());
    if state != Some(expected_state) {
        respond(stream, 400, "State mismatch")?;
        return Err(Error::StateMismatch);
    }

    if params.iter().any(|(key, value)| key == "error" && value == "access_denied") {
        respond(stream, 200, "Authorization canceled. You can close this tab.")?;
        return Ok(Callback::Denied);
    }

    match params.iter().find(|(key, _)| key == "code").map(|(_, value)| value.clone()) {
        Some(code) if !code.is_empty() => {
            respond(stream, 200, "Authorized. You can close this tab.")?;
            Ok(Callback::Code(code))
        }
        _ => {
            respond(stream, 400, "Missing code")?;
            Ok(Callback::Other)
        }
    }
}

fn read_http_request(stream: &mut TcpStream) -> Result<String, Error> {
    let mut buf = Vec::new();
    let mut chunk = [0u8; 512];
    loop {
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => {
                buf.extend_from_slice(&chunk[..n]);
                if buf.windows(4).any(|window| window == b"\r\n\r\n") || buf.len() > 8192 {
                    break;
                }
            }
            Err(err)
                if err.kind() == io::ErrorKind::WouldBlock
                    || err.kind() == io::ErrorKind::TimedOut =>
            {
                break;
            }
            Err(err) => {
                return Err(Error::Io(format!("failed to read browser callback: {err}")));
            }
        }
    }
    String::from_utf8(buf).map_err(|_| Error::Io("callback request was not UTF-8".into()))
}

fn request_target(request: &str) -> Option<&str> {
    let line = request.lines().next()?;
    let mut parts = line.split_whitespace();
    let method = parts.next()?;
    let target = parts.next()?;
    if method == "GET" {
        Some(target)
    } else {
        None
    }
}

fn split_target(target: &str) -> (&str, Option<&str>) {
    match target.split_once('?') {
        Some((path, query)) => (path, Some(query)),
        None => (target, None),
    }
}

fn parse_query(query: &str) -> Vec<(String, String)> {
    query
        .split('&')
        .filter(|pair| !pair.is_empty())
        .map(|pair| match pair.split_once('=') {
            Some((key, value)) => (percent_decode(key), percent_decode(value)),
            None => (percent_decode(pair), String::new()),
        })
        .collect()
}

fn percent_decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'+' => {
                out.push(b' ');
                i += 1;
            }
            b'%' if i + 2 < bytes.len() => {
                let hex = &value[i + 1..i + 3];
                match u8::from_str_radix(hex, 16) {
                    Ok(byte) => {
                        out.push(byte);
                        i += 3;
                    }
                    Err(_) => {
                        out.push(b'%');
                        i += 1;
                    }
                }
            }
            byte => {
                out.push(byte);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn respond(stream: &mut TcpStream, status: u16, body: &str) -> Result<(), Error> {
    let reason = match status {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        _ => "OK",
    };
    let html = format!("<!doctype html><title>Drift CLI</title><p>{body}</p>");
    let response = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{html}",
        html.len()
    );
    stream
        .write_all(response.as_bytes())
        .and_then(|_| stream.flush())
        .map_err(|err| Error::Io(format!("failed to answer browser: {err}")))
}

fn open_browser(url: &str) {
    let command = if cfg!(target_os = "macos") {
        "open"
    } else if cfg!(target_os = "windows") {
        "cmd"
    } else {
        "xdg-open"
    };

    let mut cmd = std::process::Command::new(command);
    if cfg!(target_os = "windows") {
        cmd.args(["/C", "start", "", url]);
    } else {
        cmd.arg(url);
    }
    let _ = cmd.stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
}

fn random_state() -> Result<String, Error> {
    let mut buf = [0u8; 16];
    let mut file = std::fs::File::open("/dev/urandom")
        .map_err(|err| Error::Io(format!("failed to read /dev/urandom: {err}")))?;
    file.read_exact(&mut buf)
        .map_err(|err| Error::Io(format!("failed to read /dev/urandom: {err}")))?;
    Ok(buf.iter().map(|byte| format!("{byte:02x}")).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_query_decodes_code_and_state() {
        let params = parse_query("code=abc%2Fdef&state=cli-state-token");
        assert_eq!(
            params,
            vec![
                ("code".into(), "abc/def".into()),
                ("state".into(), "cli-state-token".into())
            ]
        );
    }

    #[test]
    fn request_target_reads_get_path() {
        let request = "GET /callback?code=one&state=two HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n";
        assert_eq!(
            request_target(request),
            Some("/callback?code=one&state=two")
        );
    }
}
