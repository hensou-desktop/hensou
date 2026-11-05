//! The command line: `hensou-files`, `hensou-files <path|uri>...` and
//! `hensou-files --daemon`. Parsing is pure; the caller supplies the working
//! directory, so a forwarded request always carries an absolute location.

use hensou_files_model::{Location, Place};
use serde::{Deserialize, Serialize};
use std::path::{Component, Path, PathBuf};

/// One thing a launch asks the resident process to do.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "request", rename_all = "kebab-case")]
pub enum Request {
    /// Open the Computer window ("Myoko" in Platinum, My Computer in Memphis).
    Computer,
    /// Open a folder window, or bring it to the front.
    Open { location: Location },
    /// Start without windows. A running instance ignores it.
    Daemon,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Launch {
    pub requests: Vec<Request>,
    /// Use the fixture service instead of the real backend.
    pub fixture: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CliError {
    Help,
    UnknownOption(String),
    Unsupported(String),
}

impl std::fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CliError::Help => f.write_str(USAGE),
            CliError::UnknownOption(o) => write!(f, "Unknown option {o}\n{USAGE}"),
            CliError::Unsupported(t) => write!(
                f,
                "Files cannot open {t}: use a path, file://, sftp:// or ssh:// location"
            ),
        }
    }
}

pub const USAGE: &str = "Usage: hensou-files [--daemon] [--fixture] [PATH|URI...]";

pub fn parse(args: &[String], cwd: &Path) -> Result<Launch, CliError> {
    let mut requests = Vec::new();
    let mut fixture = false;
    let mut daemon = false;
    let mut only_targets = false;
    for arg in args {
        if !only_targets && arg.starts_with("--") {
            match arg.as_str() {
                "--" => only_targets = true,
                "--daemon" => daemon = true,
                "--fixture" => fixture = true,
                "--help" => return Err(CliError::Help),
                other => return Err(CliError::UnknownOption(other.into())),
            }
            continue;
        }
        if arg.is_empty() {
            continue;
        }
        requests.push(target(arg, cwd)?);
    }
    if daemon {
        requests.insert(0, Request::Daemon);
    } else if requests.is_empty() {
        requests.push(Request::Computer);
    }
    Ok(Launch { requests, fixture })
}

/// A path or URI as a request.
pub fn target(arg: &str, cwd: &Path) -> Result<Request, CliError> {
    let unsupported = || CliError::Unsupported(arg.into());
    if let Some((scheme, rest)) = split_scheme(arg) {
        return match scheme.as_str() {
            "file" => {
                let path = rest.strip_prefix("//").ok_or_else(unsupported)?;
                // file://host/path: only the local host (empty or localhost).
                let slash = path.find('/').ok_or_else(unsupported)?;
                let host = &path[..slash];
                if !host.is_empty() && host != "localhost" {
                    return Err(unsupported());
                }
                let decoded = percent_decode(&path[slash..]).ok_or_else(unsupported)?;
                Ok(open(Location::local(normalize(Path::new(&decoded)))))
            }
            "sftp" | "ssh" => {
                let path = rest.strip_prefix("//").ok_or_else(unsupported)?;
                let (authority, remote) = match path.find('/') {
                    Some(i) => (&path[..i], &path[i..]),
                    None => (path, "/"),
                };
                // The SSH Hosts are the named hosts of ~/.ssh/config; a user
                // or port in the URI belongs to that config, not to Files.
                let host = authority.rsplit('@').next().unwrap_or(authority);
                let host = host.split(':').next().unwrap_or(host);
                if host.is_empty() {
                    return Err(unsupported());
                }
                let decoded = percent_decode(remote).ok_or_else(unsupported)?;
                Ok(open(Location::host(host, normalize(Path::new(&decoded)))))
            }
            "computer" => Ok(Request::Computer),
            "trash" => Ok(open(Location::virtual_place(Place::Trash))),
            _ if rest.starts_with("//") => Err(unsupported()),
            // "notes:2024" is a relative file name, not a URI.
            _ => Ok(open(Location::local(normalize(&cwd.join(arg))))),
        };
    }
    let path = Path::new(arg);
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        cwd.join(path)
    };
    Ok(open(Location::local(normalize(&absolute))))
}

fn open(location: Location) -> Request {
    Request::Open { location }
}

fn split_scheme(arg: &str) -> Option<(String, &str)> {
    let colon = arg.find(':')?;
    let scheme = &arg[..colon];
    let valid = !scheme.is_empty()
        && scheme.chars().next()?.is_ascii_alphabetic()
        && scheme
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '-' | '.'));
    valid.then(|| (scheme.to_ascii_lowercase(), &arg[colon + 1..]))
}

fn percent_decode(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' {
            let hex = text.get(i + 1..i + 3)?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

/// Removes `.` and `..` lexically. Links are not resolved: an alias opens
/// the folder it names, at the path the user gave.
pub fn normalize(path: &Path) -> PathBuf {
    let mut out = PathBuf::from("/");
    for part in path.components() {
        match part {
            Component::ParentDir => {
                out.pop();
            }
            Component::Normal(name) => out.push(name),
            Component::RootDir | Component::CurDir | Component::Prefix(_) => {}
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(list: &[&str]) -> Vec<String> {
        list.iter().map(|s| s.to_string()).collect()
    }

    fn run(list: &[&str]) -> Result<Launch, CliError> {
        parse(&args(list), Path::new("/home/fixture/work"))
    }

    #[test]
    fn no_argument_opens_the_computer_window() {
        assert_eq!(run(&[]).unwrap().requests, vec![Request::Computer]);
    }

    #[test]
    fn daemon_starts_without_windows() {
        let launch = run(&["--daemon"]).unwrap();
        assert_eq!(launch.requests, vec![Request::Daemon]);
        assert!(!launch.fixture);
    }

    #[test]
    fn relative_paths_become_absolute_and_normal() {
        assert_eq!(
            run(&["../Documents/./a"]).unwrap().requests,
            vec![open(Location::local("/home/fixture/Documents/a"))]
        );
    }

    #[test]
    fn file_uris_decode_percent_escapes() {
        assert_eq!(
            run(&["file:///home/fixture/My%20Folder"]).unwrap().requests,
            vec![open(Location::local("/home/fixture/My Folder"))]
        );
        assert!(run(&["file://elsewhere/x"]).is_err());
    }

    #[test]
    fn ssh_uris_name_the_configured_host() {
        assert_eq!(
            run(&["sftp://simon@fuji:22/srv/media", "ssh://kaiju"])
                .unwrap()
                .requests,
            vec![
                open(Location::host("fuji", "/srv/media")),
                open(Location::host("kaiju", "/")),
            ]
        );
    }

    #[test]
    fn several_targets_open_several_windows_and_fixture_is_a_flag() {
        let launch = run(&["--fixture", "/a", "trash:///"]).unwrap();
        assert!(launch.fixture);
        assert_eq!(
            launch.requests,
            vec![
                open(Location::local("/a")),
                open(Location::virtual_place(Place::Trash))
            ]
        );
    }

    #[test]
    fn unknown_schemes_and_options_are_refused() {
        assert!(matches!(run(&["http://x/"]), Err(CliError::Unsupported(_))));
        assert!(matches!(run(&["--bogus"]), Err(CliError::UnknownOption(_))));
        assert_eq!(
            run(&["--", "--daemon"]).unwrap().requests,
            vec![open(Location::local("/home/fixture/work/--daemon"))]
        );
    }

    #[test]
    fn requests_round_trip_as_json_lines() {
        let request = open(Location::host("fuji", "/srv"));
        let line = serde_json::to_string(&request).unwrap();
        assert!(!line.contains('\n'));
        assert_eq!(serde_json::from_str::<Request>(&line).unwrap(), request);
    }
}
