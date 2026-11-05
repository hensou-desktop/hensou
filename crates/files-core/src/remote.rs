use super::*;
use futures_util::TryStreamExt;
use openssh_sftp_client::{Sftp, metadata::MetaData};
use std::os::unix::fs::OpenOptionsExt;
use std::{
    io::{Read, Seek, SeekFrom, Write},
    process::Command as Process,
    time::Instant,
};
use tokio::io::AsyncSeekExt;

pub(crate) struct Host {
    connection: Option<Arc<Sftp>>,
    session: Option<Arc<openssh::Session>>,
    pending: Option<(String, HostKeyPrompt)>,
    blocked: bool,
    rejected: bool,
    pub retry_at: Instant,
    attempt: u32,
    since: i64,
    touched: Instant,
}
impl Default for Host {
    fn default() -> Self {
        Self {
            connection: None,
            session: None,
            pending: None,
            blocked: false,
            rejected: false,
            retry_at: Instant::now(),
            attempt: 0,
            since: now(),
            touched: Instant::now(),
        }
    }
}
/// The concrete `Host` names in an OpenSSH client configuration, following
/// `Include` (relative paths resolve against `~/.ssh`, globs expand, depth is
/// bounded as in OpenSSH). Patterns and negations are not hosts.
pub(crate) fn host_names(path: &Path) -> Vec<String> {
    let mut names = vec![];
    let ssh_dir = path.parent().map(Path::to_path_buf).unwrap_or_default();
    collect_hosts(path, &ssh_dir, 0, &mut names);
    names.sort();
    names.dedup();
    names
}

const INCLUDE_DEPTH: usize = 16;

fn collect_hosts(path: &Path, ssh_dir: &Path, depth: usize, names: &mut Vec<String>) {
    if depth > INCLUDE_DEPTH {
        return;
    }
    let Ok(text) = fs::read_to_string(path) else {
        return;
    };
    for line in text.lines() {
        let Some((keyword, args)) = directive(line) else {
            continue;
        };
        if keyword.eq_ignore_ascii_case("Host") {
            names.extend(
                arguments(args)
                    .filter(|s| !s.contains(['*', '?', '!']) && !s.starts_with('-'))
                    .map(str::to_owned),
            );
        } else if keyword.eq_ignore_ascii_case("Include") {
            for pattern in arguments(args) {
                for file in expand_include(pattern, ssh_dir) {
                    collect_hosts(&file, ssh_dir, depth + 1, names);
                }
            }
        }
    }
}

/// Splits `Keyword args`, `Keyword=args` or `Keyword = args`; skips comments.
fn directive(line: &str) -> Option<(&str, &str)> {
    let line = line.trim();
    if line.is_empty() || line.starts_with('#') {
        return None;
    }
    let end = line.find(|c: char| c.is_whitespace() || c == '=')?;
    let (keyword, rest) = line.split_at(end);
    let rest = rest.trim_start();
    let rest = rest.strip_prefix('=').unwrap_or(rest).trim();
    Some((keyword, rest))
}

/// Whitespace-separated arguments, honouring double quotes and stopping at a
/// comment.
fn arguments(args: &str) -> impl Iterator<Item = &str> {
    let mut out = vec![];
    let mut rest = args;
    loop {
        rest = rest.trim_start();
        if rest.is_empty() || rest.starts_with('#') {
            break;
        }
        if let Some(quoted) = rest.strip_prefix('"') {
            let end = quoted.find('"').unwrap_or(quoted.len());
            out.push(&quoted[..end]);
            rest = quoted.get(end + 1..).unwrap_or("");
        } else {
            let end = rest.find(char::is_whitespace).unwrap_or(rest.len());
            out.push(&rest[..end]);
            rest = &rest[end..];
        }
    }
    out.into_iter()
}

fn expand_include(pattern: &str, ssh_dir: &Path) -> Vec<std::path::PathBuf> {
    let home = std::env::var_os("HOME").map(std::path::PathBuf::from);
    let path = if let Some(rest) = pattern.strip_prefix("~/") {
        match home {
            Some(home) => home.join(rest),
            None => return vec![],
        }
    } else if Path::new(pattern).is_absolute() {
        std::path::PathBuf::from(pattern)
    } else {
        ssh_dir.join(pattern)
    };
    // Expand every component, as glob(3) does for OpenSSH: `*`, `?` and
    // `[...]` may appear in directories as well as the file name.
    let mut found = vec![std::path::PathBuf::new()];
    for component in path.components() {
        let part = component.as_os_str();
        let Some(text) = part.to_str().filter(|t| t.contains(['*', '?', '['])) else {
            found.iter_mut().for_each(|p| p.push(part));
            continue;
        };
        let mut next = vec![];
        for base in &found {
            let Ok(entries) = fs::read_dir(base) else {
                continue;
            };
            let mut matches: Vec<_> = entries
                .filter_map(Result::ok)
                .filter(|e| {
                    e.file_name()
                        .to_str()
                        .is_some_and(|f| !f.starts_with('.') && glob_match(text, f))
                })
                .map(|e| e.path())
                .collect();
            matches.sort();
            next.extend(matches);
        }
        found = next;
    }
    found.retain(|p| p.is_file());
    found
}

/// Shell-style matching of one path component: `*`, `?` and bracket
/// classes (`[ab]`, `[a-z]`, `[!x]`).
fn glob_match(pattern: &str, text: &str) -> bool {
    fn class(p: &[char], c: char) -> Option<(bool, usize)> {
        let mut i = 1;
        let negate = matches!(p.get(i), Some('!' | '^'));
        if negate {
            i += 1;
        }
        let mut hit = false;
        let mut first = true;
        while let Some(&a) = p.get(i) {
            if a == ']' && !first {
                return Some((hit != negate, i + 1));
            }
            first = false;
            if p.get(i + 1) == Some(&'-') && p.get(i + 2).is_some_and(|b| *b != ']') {
                let b = p[i + 2];
                hit |= a <= c && c <= b;
                i += 3;
            } else {
                hit |= a == c;
                i += 1;
            }
        }
        None
    }
    fn go(p: &[char], t: &[char]) -> bool {
        match p.first() {
            None => t.is_empty(),
            Some('*') => go(&p[1..], t) || (!t.is_empty() && go(p, &t[1..])),
            Some('?') => !t.is_empty() && go(&p[1..], &t[1..]),
            Some('[') => match (class(p, *t.first().unwrap_or(&'\0')), t.first()) {
                (Some((true, used)), Some(_)) => go(&p[used..], &t[1..]),
                (Some(_), _) => false,
                (None, Some('[')) => go(&p[1..], &t[1..]),
                (None, _) => false,
            },
            Some(a) => t.first() == Some(a) && go(&p[1..], &t[1..]),
        }
    }
    let p: Vec<char> = pattern.chars().collect();
    let t: Vec<char> = text.chars().collect();
    go(&p, &t)
}

#[cfg(test)]
mod host_name_tests {
    use super::host_names;
    use std::fs;

    #[test]
    fn hosts_follow_includes_and_equals_syntax() {
        let dir = tempfile::tempdir().unwrap();
        let ssh = dir.path();
        fs::create_dir_all(ssh.join("config.d")).unwrap();
        fs::create_dir_all(ssh.join("hosts/work")).unwrap();
        fs::write(
            ssh.join("config"),
            "Include config.d/*.conf hosts/*/config config.d/[ab].list\n\
             Include config\n\
             Host=fuji kaiju # comment\nHost * !bad\n  HostName x\nhost \"quoted\"\n",
        )
        .unwrap();
        fs::write(ssh.join("config.d/a.conf"), "Host aka\nInclude ../config\n").unwrap();
        fs::write(ssh.join("config.d/b.txt"), "Host ignored\n").unwrap();
        fs::write(ssh.join("config.d/b.list"), "Host listed\n").unwrap();
        fs::write(ssh.join("config.d/c.list"), "Host unlisted\n").unwrap();
        fs::write(ssh.join("hosts/work/config"), "Host office\n").unwrap();
        assert_eq!(
            host_names(&ssh.join("config")),
            ["aka", "fuji", "kaiju", "listed", "office", "quoted"]
        );
    }

    #[test]
    fn bracket_classes_match_like_glob() {
        use super::glob_match;
        assert!(glob_match("[ab].conf", "a.conf"));
        assert!(!glob_match("[ab].conf", "c.conf"));
        assert!(glob_match("[a-c]?", "bz"));
        assert!(glob_match("[!x]*", "yes"));
        assert!(!glob_match("[!x]*", "xen"));
    }
}
