//! A fixture provider for shell development: serves fixed icons, keeps moves
//! in memory and answers every message type. Not shipped to users.
//!
//! Usage: `hensou-desktop-stub [SOCKET]` (default: the protocol socket path).

use hensou_desktop_protocol::*;
use std::io::BufReader;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

struct Shared {
    icons: Vec<DesktopIcon>,
    snap: bool,
}

const GRID: GridSpec = GridSpec {
    cell_width: 80,
    cell_height: 72,
};

fn icon(id: &str, kind: IconKind, label: &str, generic: &str, row: i32) -> DesktopIcon {
    DesktopIcon {
        id: id.into(),
        kind,
        label: label.into(),
        art: IconArt::Generic {
            kind: generic.into(),
            path: PathBuf::new(),
        },
        position: Point {
            x: 16,
            y: 16 + row * GRID.cell_height as i32,
        },
        available: true,
        reason: None,
        full: (kind == IconKind::Trash).then_some(true),
        ejectable: (kind == IconKind::Volume).then_some(true),
    }
}

fn fixtures(theme: Theme) -> Vec<DesktopIcon> {
    let memphis = theme == Theme::Memphis;
    let mut icons = vec![
        icon(
            "computer",
            IconKind::Computer,
            if memphis { "My Computer" } else { "Myoko" },
            "computer",
            0,
        ),
        icon(
            "ssh-hosts",
            IconKind::SshHosts,
            if memphis {
                "Network Neighborhood"
            } else {
                "SSH Hosts"
            },
            "folder",
            1,
        ),
        icon(
            "trash",
            IconKind::Trash,
            if memphis { "Recycle Bin" } else { "Trash" },
            "trash",
            2,
        ),
        icon("file:notes.txt", IconKind::File, "notes.txt", "text", 3),
        icon("file:Projects", IconKind::Folder, "Projects", "folder", 4),
        DesktopIcon {
            art: IconArt::Lettermark {
                letter: 'K',
                tint: "#3a6ea5".into(),
            },
            ..icon(
                "file:krita.desktop",
                IconKind::Launcher,
                "Krita",
                "application",
                5,
            )
        },
        icon("file:Docs link", IconKind::Alias, "Docs link", "folder", 6),
    ];
    // Memphis lists volumes inside My Computer, not on the desktop.
    if !memphis {
        icons.push(icon("volume:sdb1", IconKind::Volume, "USB", "volume", 7));
    }
    icons
}

fn serve(stream: UnixStream, shared: Arc<Mutex<Shared>>) -> std::io::Result<()> {
    let mut out = stream.try_clone()?;
    let mut input = BufReader::new(stream);
    while let Some(message) = read_line::<ShellMessage>(&mut input)? {
        let reply = match message {
            ShellMessage::Hello { major, .. } if !compatible(major) => {
                write_line(
                    &mut out,
                    &ProviderMessage::Error {
                        code: "version".into(),
                        message: format!("provider speaks {PROTOCOL_MAJOR}.x"),
                        ids: vec![],
                    },
                )?;
                return Ok(());
            }
            ShellMessage::Hello { .. } => Some(ProviderMessage::Hello {
                major: PROTOCOL_MAJOR,
                minor: PROTOCOL_MINOR,
            }),
            ShellMessage::Subscribe { theme, .. } => {
                let mut s = shared.lock().unwrap();
                let moved: Vec<(String, Point)> =
                    s.icons.iter().map(|i| (i.id.clone(), i.position)).collect();
                let mut icons = fixtures(theme);
                for icon in &mut icons {
                    if let Some((_, p)) = moved.iter().find(|(id, _)| *id == icon.id) {
                        icon.position = *p;
                    }
                }
                s.icons = icons.clone();
                Some(ProviderMessage::Snapshot {
                    icons,
                    snap: s.snap,
                    grid: GRID,
                })
            }
            ShellMessage::Move { moves } => {
                let mut s = shared.lock().unwrap();
                let mut upsert = Vec::new();
                for (id, p) in moves {
                    if let Some(icon) = s.icons.iter_mut().find(|i| i.id == id) {
                        icon.position = p;
                        upsert.push(icon.clone());
                    }
                }
                Some(ProviderMessage::Changed {
                    upsert,
                    removed: vec![],
                })
            }
            ShellMessage::CheckTrash { request, ids } => Some(ProviderMessage::ConfirmNeeded {
                request,
                confirmation: Confirmation::MoveToTrash {
                    count: ids.len() as u32,
                },
                ids,
            }),
            ShellMessage::CheckEmptyTrash { request } => Some(ProviderMessage::ConfirmNeeded {
                request,
                ids: vec!["trash".into()],
                confirmation: Confirmation::EmptyTrash { count: 3 },
            }),
            ShellMessage::Trash { ids } | ShellMessage::DeletePermanently { ids } => {
                let mut s = shared.lock().unwrap();
                s.icons.retain(|i| !ids.contains(&i.id));
                Some(ProviderMessage::Changed {
                    upsert: vec![],
                    removed: ids,
                })
            }
            ShellMessage::Eject { id } => Some(ProviderMessage::Error {
                code: "busy".into(),
                message: "The volume is in use by ghostty.".into(),
                ids: vec![id],
            }),
            ShellMessage::SetSnap { snap } => {
                shared.lock().unwrap().snap = snap;
                Some(ProviderMessage::Snap { snap })
            }
            ShellMessage::Arrange { .. } => {
                let mut s = shared.lock().unwrap();
                for (row, icon) in s.icons.iter_mut().enumerate() {
                    icon.position = Point {
                        x: 16,
                        y: 16 + row as i32 * GRID.cell_height as i32,
                    };
                }
                Some(ProviderMessage::Changed {
                    upsert: s.icons.clone(),
                    removed: vec![],
                })
            }
            ShellMessage::Rename { id, name } => {
                let mut s = shared.lock().unwrap();
                s.icons.iter_mut().find(|i| i.id == id).map(|icon| {
                    icon.label = name;
                    ProviderMessage::Changed {
                        upsert: vec![icon.clone()],
                        removed: vec![],
                    }
                })
            }
            ShellMessage::Open { .. } | ShellMessage::Drop { .. } | ShellMessage::EmptyTrash => {
                None
            }
        };
        if let Some(reply) = reply {
            write_line(&mut out, &reply)?;
        }
    }
    Ok(())
}

fn main() -> std::io::Result<()> {
    let path = std::env::args_os()
        .nth(1)
        .map(PathBuf::from)
        .or_else(socket_path)
        .ok_or_else(|| std::io::Error::other("XDG_RUNTIME_DIR is not set"))?;
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let _ = std::fs::remove_file(&path);
    let listener = UnixListener::bind(&path)?;
    eprintln!("hensou-desktop-stub listening on {}", path.display());
    let shared = Arc::new(Mutex::new(Shared {
        icons: Vec::new(),
        snap: false,
    }));
    for stream in listener.incoming() {
        let stream = stream?;
        let shared = shared.clone();
        std::thread::spawn(move || {
            if let Err(e) = serve(stream, shared) {
                eprintln!("client: {e}");
            }
        });
    }
    Ok(())
}
