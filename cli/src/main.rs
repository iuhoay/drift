mod auth;
mod client;
mod config;

use clap::{Parser, Subcommand, ValueEnum};
use client::{Client, EntriesQuery, EntryDetail, EntrySummary, Subscription};
use config::Settings;
use serde::Serialize;
use std::process;

#[derive(Debug, Parser)]
#[command(
    name = "drift",
    version,
    about = "CLI client for Drift, a personal RSS reader"
)]
struct Cli {
    /// Output format (default: json)
    #[arg(long, global = true, value_enum, default_value = "json")]
    output: OutputFormat,

    /// API host (overrides DRIFT_HOST and config)
    #[arg(long, global = true)]
    host: Option<String>,

    /// Bearer token (overrides DRIFT_TOKEN and config)
    #[arg(long, global = true, hide = true)]
    token: Option<String>,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum OutputFormat {
    Json,
    Text,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Log in or inspect saved credentials
    Auth {
        #[command(subcommand)]
        command: AuthCommand,
    },
    /// List subscribed feeds
    Feeds,
    /// List unread inbox entries
    Inbox {
        /// Limit to one feed
        #[arg(long, value_name = "feed_id")]
        feed: Option<i64>,
        /// Page size (1–50; server default 20)
        #[arg(long, value_parser = clap::value_parser!(u32).range(1..=50))]
        limit: Option<u32>,
    },
    /// Search entries
    Search {
        query: String,
        /// Page size (1–50; server default 20)
        #[arg(long, value_parser = clap::value_parser!(u32).range(1..=50))]
        limit: Option<u32>,
    },
    /// Show one entry body
    Show { id: i64 },
}

#[derive(Debug, Subcommand)]
enum AuthCommand {
    /// Open a browser to sign in (GitHub / Google / password) and store a token
    Login,
    /// Print host and masked token; ping the API when a token is present
    Status,
}

fn main() {
    if let Err(err) = run(Cli::parse()) {
        eprintln!("{err}");
        process::exit(1);
    }
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    let output = cli.output;

    match cli.command {
        Command::Auth {
            command: AuthCommand::Login,
        } => {
            let host = cli
                .host
                .or_else(|| nonempty_env("DRIFT_HOST"))
                .unwrap_or_else(|| config::DEFAULT_HOST.to_string());
            let (settings, path) = if let Some(token) = cli.token {
                let path = config::config_path();
                config::save(&path, &host, &token)?;
                (
                    config::Settings {
                        host: config::normalize_host(&host),
                        token: Some(token),
                    },
                    path,
                )
            } else {
                auth::login_via_browser(&host)?
            };
            match output {
                OutputFormat::Json => print_json(&LoginOutput {
                    host: settings.host,
                    path: path.display().to_string(),
                })?,
                OutputFormat::Text => {
                    println!("saved credentials to {}", path.display());
                }
            }
        }
        Command::Auth {
            command: AuthCommand::Status,
        } => {
            let settings = config::load(cli.host, cli.token)?;
            auth_status(output, &settings)?;
        }
        Command::Feeds => {
            let client = connect(cli.host, cli.token)?;
            let payload = client.subscriptions()?;
            match output {
                OutputFormat::Json => print_json(&payload)?,
                OutputFormat::Text => {
                    for subscription in &payload.subscriptions {
                        print_feed_line(subscription);
                    }
                }
            }
        }
        Command::Inbox { feed, limit } => {
            let client = connect(cli.host, cli.token)?;
            let payload = client.entries(&EntriesQuery {
                scope: Some("unread"),
                feed_id: feed,
                q: None,
                limit,
            })?;
            print_entries(output, &payload.entries, &payload)?;
        }
        Command::Search { query, limit } => {
            let client = connect(cli.host, cli.token)?;
            let payload = client.entries(&EntriesQuery {
                scope: Some("all"),
                feed_id: None,
                q: Some(&query),
                limit,
            })?;
            print_entries(output, &payload.entries, &payload)?;
        }
        Command::Show { id } => {
            let client = connect(cli.host, cli.token)?;
            let entry = client.entry(id)?;
            match output {
                OutputFormat::Json => print_json(&entry)?,
                OutputFormat::Text => print_show(&entry),
            }
        }
    }

    Ok(())
}

fn connect(
    flag_host: Option<String>,
    flag_token: Option<String>,
) -> Result<Client, Box<dyn std::error::Error>> {
    let settings = config::load(flag_host, flag_token)?;
    let token = settings.require_token()?.to_string();
    Ok(Client::new(settings.host, token))
}

fn auth_status(
    output: OutputFormat,
    settings: &Settings,
) -> Result<(), Box<dyn std::error::Error>> {
    let masked = settings.token.as_deref().map(config::mask_token);
    let status = match settings.token.as_deref() {
        None => "not logged in",
        Some(token) => match Client::new(&settings.host, token).subscriptions() {
            Ok(_) => "ok",
            Err(client::Error::Unauthorized) => "unauthorized",
            Err(err) => return Err(err.into()),
        },
    };

    match output {
        OutputFormat::Json => print_json(&StatusOutput {
            host: settings.host.clone(),
            token: masked.clone(),
            status: status.to_string(),
        })?,
        OutputFormat::Text => {
            println!("host: {}", settings.host);
            match masked {
                Some(token) => println!("token: {token}"),
                None => println!("token: (none)"),
            }
            println!("status: {status}");
        }
    }

    if status == "ok" {
        Ok(())
    } else if status == "not logged in" {
        Err(config::Error::MissingToken.into())
    } else {
        Err(client::Error::Unauthorized.into())
    }
}

fn print_entries(
    output: OutputFormat,
    entries: &[EntrySummary],
    payload: &impl Serialize,
) -> Result<(), Box<dyn std::error::Error>> {
    match output {
        OutputFormat::Json => print_json(payload)?,
        OutputFormat::Text => {
            for entry in entries {
                print_entry_line(entry);
            }
        }
    }
    Ok(())
}

fn print_feed_line(subscription: &Subscription) {
    println!("{}  {}", subscription.feed_id, subscription.title);
}

fn print_entry_line(entry: &EntrySummary) {
    let date = entry.published_at.as_deref().and_then(ymd).unwrap_or("-");
    let title = entry.title.as_deref().unwrap_or("(untitled)");
    println!("{}  {date}  {}  {title}", entry.id, entry.feed.title);
}

fn print_show(entry: &EntryDetail) {
    println!("{}", entry.title.as_deref().unwrap_or("(untitled)"));
    println!("{}", entry.feed.title);
    println!("{}", entry.url);
    println!("{}", entry.author.as_deref().unwrap_or(""));
    println!("{}", entry.published_at.as_deref().unwrap_or(""));
    println!();
    println!("{}", entry.body.as_deref().unwrap_or(""));
}

fn ymd(value: &str) -> Option<&str> {
    let date = value.get(..10)?;
    if date.as_bytes().get(4) == Some(&b'-') && date.as_bytes().get(7) == Some(&b'-') {
        Some(date)
    } else {
        None
    }
}

fn nonempty_env(key: &str) -> Option<String> {
    std::env::var(key).ok().and_then(|value| {
        let trimmed = value.trim().to_string();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    })
}

fn print_json(value: &impl Serialize) -> Result<(), Box<dyn std::error::Error>> {
    println!("{}", serde_json::to_string(value)?);
    Ok(())
}

#[derive(Serialize)]
struct LoginOutput {
    host: String,
    path: String,
}

#[derive(Serialize)]
struct StatusOutput {
    host: String,
    token: Option<String>,
    status: String,
}
