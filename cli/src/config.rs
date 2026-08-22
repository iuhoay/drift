use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

pub const DEFAULT_HOST: &str = "https://rdrift.app";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Settings {
    pub host: String,
    pub token: Option<String>,
}

impl Settings {
    pub fn require_token(&self) -> Result<&str, Error> {
        self.token
            .as_deref()
            .filter(|token| !token.is_empty())
            .ok_or(Error::MissingToken)
    }
}

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FileConfig {
    #[serde(default)]
    pub host: Option<String>,
    #[serde(default)]
    pub token: Option<String>,
}

#[derive(Debug, Default, Clone)]
pub struct Sources {
    pub file: Option<FileConfig>,
    pub env_host: Option<String>,
    pub env_token: Option<String>,
    pub flag_host: Option<String>,
    pub flag_token: Option<String>,
}

#[derive(Debug)]
pub enum Error {
    MissingToken,
    Io(String),
    Parse(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingToken => write!(f, "not logged in — run `drift auth login`"),
            Self::Io(msg) | Self::Parse(msg) => write!(f, "{msg}"),
        }
    }
}

impl std::error::Error for Error {}

pub fn config_dir() -> PathBuf {
    match std::env::var_os("XDG_CONFIG_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir).join("drift"),
        _ => dirs::home_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join(".config")
            .join("drift"),
    }
}

pub fn config_path() -> PathBuf {
    config_dir().join("config.toml")
}

pub fn normalize_host(host: &str) -> String {
    host.trim().trim_end_matches('/').to_string()
}

fn nonempty(value: Option<String>) -> Option<String> {
    value.and_then(|value| {
        let trimmed = value.trim().to_string();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    })
}

/// Highest wins: flag → env → config file → default host.
pub fn resolve(sources: Sources) -> Settings {
    let file = sources.file.unwrap_or_default();
    let host = nonempty(sources.flag_host)
        .or_else(|| nonempty(sources.env_host))
        .or_else(|| nonempty(file.host))
        .unwrap_or_else(|| DEFAULT_HOST.to_string());
    let token = nonempty(sources.flag_token)
        .or_else(|| nonempty(sources.env_token))
        .or_else(|| nonempty(file.token));

    Settings {
        host: normalize_host(&host),
        token,
    }
}

pub fn load_file(path: &Path) -> Result<Option<FileConfig>, Error> {
    if !path.exists() {
        return Ok(None);
    }
    let text = fs::read_to_string(path)
        .map_err(|err| Error::Io(format!("failed to read {}: {err}", path.display())))?;
    let parsed = toml::from_str(&text)
        .map_err(|err| Error::Parse(format!("invalid TOML in {}: {err}", path.display())))?;
    Ok(Some(parsed))
}

pub fn sources_from_os(
    flag_host: Option<String>,
    flag_token: Option<String>,
) -> Result<Sources, Error> {
    Ok(Sources {
        file: load_file(&config_path())?,
        env_host: nonempty(std::env::var("DRIFT_HOST").ok()),
        env_token: nonempty(std::env::var("DRIFT_TOKEN").ok()),
        flag_host,
        flag_token,
    })
}

pub fn load(flag_host: Option<String>, flag_token: Option<String>) -> Result<Settings, Error> {
    Ok(resolve(sources_from_os(flag_host, flag_token)?))
}

pub fn save(path: &Path, host: &str, token: &str) -> Result<(), Error> {
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir)
            .map_err(|err| Error::Io(format!("failed to create {}: {err}", dir.display())))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(dir, fs::Permissions::from_mode(0o700));
        }
    }

    let file = FileConfig {
        host: Some(normalize_host(host)),
        token: Some(token.to_string()),
    };
    let text = toml::to_string_pretty(&file)
        .map_err(|err| Error::Parse(format!("failed to serialize config: {err}")))?;
    fs::write(path, text)
        .map_err(|err| Error::Io(format!("failed to write {}: {err}", path.display())))?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o600))
            .map_err(|err| Error::Io(format!("failed to chmod {}: {err}", path.display())))?;
    }

    Ok(())
}

pub fn mask_token(token: &str) -> String {
    let tail: String = token
        .chars()
        .rev()
        .take(4)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    format!("••••{tail}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, MutexGuard};

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct EnvGuard {
        _lock: MutexGuard<'static, ()>,
        saved: Vec<(&'static str, Option<String>)>,
    }

    impl EnvGuard {
        fn new() -> Self {
            let lock = ENV_LOCK.lock().unwrap_or_else(|err| err.into_inner());
            let keys = ["XDG_CONFIG_HOME", "DRIFT_HOST", "DRIFT_TOKEN"];
            let saved = keys
                .iter()
                .map(|key| (*key, std::env::var(key).ok()))
                .collect();
            for key in keys {
                std::env::remove_var(key);
            }
            Self { _lock: lock, saved }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            for (key, value) in &self.saved {
                match value {
                    Some(value) => std::env::set_var(key, value),
                    None => std::env::remove_var(key),
                }
            }
        }
    }

    #[test]
    fn flag_beats_env_beats_file() {
        let settings = resolve(Sources {
            file: Some(FileConfig {
                host: Some("https://file.example/".into()),
                token: Some("file-token".into()),
            }),
            env_host: Some("https://env.example/".into()),
            env_token: Some("env-token".into()),
            flag_host: Some("https://flag.example/".into()),
            flag_token: Some("flag-token".into()),
        });
        assert_eq!(
            settings,
            Settings {
                host: "https://flag.example".into(),
                token: Some("flag-token".into()),
            }
        );
    }

    #[test]
    fn env_beats_file_when_flags_absent() {
        let settings = resolve(Sources {
            file: Some(FileConfig {
                host: Some("https://file.example".into()),
                token: Some("file-token".into()),
            }),
            env_host: Some("https://env.example".into()),
            env_token: None,
            flag_host: None,
            flag_token: None,
        });
        assert_eq!(settings.host, "https://env.example");
        assert_eq!(settings.token.as_deref(), Some("file-token"));
    }

    #[test]
    fn empty_overrides_are_ignored() {
        let settings = resolve(Sources {
            file: Some(FileConfig {
                host: Some("https://file.example".into()),
                token: Some("file-token".into()),
            }),
            env_host: Some("   ".into()),
            env_token: Some(String::new()),
            flag_host: Some(String::new()),
            flag_token: Some("  ".into()),
        });
        assert_eq!(settings.host, "https://file.example");
        assert_eq!(settings.token.as_deref(), Some("file-token"));
    }

    #[test]
    fn missing_file_defaults_host() {
        let settings = resolve(Sources::default());
        assert_eq!(settings.host, DEFAULT_HOST);
        assert_eq!(settings.token, None);
        assert!(matches!(settings.require_token(), Err(Error::MissingToken)));
    }

    #[test]
    fn load_from_os_reads_xdg_file_and_env() {
        let _env = EnvGuard::new();
        let tmp = tempfile::tempdir().unwrap();
        let drift_dir = tmp.path().join("drift");
        fs::create_dir_all(&drift_dir).unwrap();
        fs::write(
            drift_dir.join("config.toml"),
            "host = \"https://file.example\"\ntoken = \"filetok\"\n",
        )
        .unwrap();
        std::env::set_var("XDG_CONFIG_HOME", tmp.path());
        std::env::set_var("DRIFT_TOKEN", "envtok");

        let settings = load(None, None).unwrap();
        assert_eq!(settings.host, "https://file.example");
        assert_eq!(settings.token.as_deref(), Some("envtok"));
    }

    #[test]
    fn load_from_os_flag_beats_env() {
        let _env = EnvGuard::new();
        let tmp = tempfile::tempdir().unwrap();
        std::env::set_var("XDG_CONFIG_HOME", tmp.path());
        std::env::set_var("DRIFT_HOST", "https://env.example");
        std::env::set_var("DRIFT_TOKEN", "envtok");

        let settings = load(Some("https://flag.example/".into()), Some("flagtok".into())).unwrap();
        assert_eq!(settings.host, "https://flag.example");
        assert_eq!(settings.token.as_deref(), Some("flagtok"));
    }

    #[test]
    fn save_writes_config_and_masks_token() {
        let _env = EnvGuard::new();
        let tmp = tempfile::tempdir().unwrap();
        std::env::set_var("XDG_CONFIG_HOME", tmp.path());
        let path = tmp.path().join("drift").join("config.toml");

        save(&path, DEFAULT_HOST, "secret-token-9876").unwrap();
        assert_eq!(mask_token("secret-token-9876"), "••••9876");

        let written = fs::read_to_string(&path).unwrap();
        assert!(written.contains("https://rdrift.app"));
        assert!(written.contains("secret-token-9876"));

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = fs::metadata(&path).unwrap().permissions().mode() & 0o777;
            assert_eq!(mode, 0o600);
        }
    }
}
