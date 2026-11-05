use hensou_files_model::*;
use std::{
    fs, io,
    os::unix::fs::MetadataExt,
    path::{Component, Path},
};

pub(crate) fn error(e: io::Error) -> FilesError {
    match e.kind() {
        io::ErrorKind::NotFound => FilesError::NotFound,
        io::ErrorKind::PermissionDenied => FilesError::PermissionDenied,
        io::ErrorKind::AlreadyExists => FilesError::AlreadyExists,
        _ => other(e),
    }
}
pub(crate) fn other(e: impl std::fmt::Display) -> FilesError {
    FilesError::Other {
        message: e.to_string(),
    }
}
pub(crate) fn name(value: &str) -> Result<(), FilesError> {
    let mut parts = Path::new(value).components();
    if !matches!(parts.next(), Some(Component::Normal(_)))
        || parts.next().is_some()
        || value.contains('\0')
    {
        return Err(other("name must be one non-empty path component"));
    }
    Ok(())
}
pub(crate) fn validate(location: &Location) -> Result<(), FilesError> {
    if matches!(location.place, Place::Local | Place::Host { .. }) && !location.path.is_absolute() {
        return Err(other(
            "filesystem locations must be absolute and contain no parent traversal",
        ));
    }
    Ok(())
}
pub(crate) fn icon(path: &Path, kind: EntryKind) -> IconHint {
    let mut hint = IconHint {
        name: if kind == EntryKind::Folder {
            "folder"
        } else {
            "application-octet-stream"
        }
        .into(),
        launcher_icon: None,
        launcher_name: None,
    };
    if kind == EntryKind::File {
        hint.name = mime_guess::from_path(path)
            .first_or_octet_stream()
            .essence_str()
            .replace('/', "-");
    }
    if kind == EntryKind::Launcher
        && fs::metadata(path).is_ok_and(|metadata| metadata.len() <= 1024 * 1024)
        && let Ok(text) = fs::read_to_string(path)
    {
        let fields = desktop_fields(&text);
        hint.launcher_icon = fields.get("Icon").cloned();
        hint.launcher_name = fields.get("Name").cloned();
    }
    hint
}
pub(crate) fn desktop_fields(text: &str) -> std::collections::BTreeMap<String, String> {
    let mut active = false;
    let mut fields = std::collections::BTreeMap::new();
    for line in text.lines().map(str::trim) {
        if line.starts_with('[') {
            active = line == "[Desktop Entry]";
        } else if active && let Some((k, v)) = line.split_once('=') {
            fields.insert(k.into(), v.into());
        }
    }
    fields
}
pub(crate) fn kind(path: &Path, directory: bool, link: bool) -> EntryKind {
    if link {
        EntryKind::Alias
    } else if directory {
        EntryKind::Folder
    } else if path.extension().is_some_and(|s| s == "desktop") {
        EntryKind::Launcher
    } else {
        EntryKind::File
    }
}
pub(crate) fn info(location: &Location) -> Result<Entry, FilesError> {
    validate(location)?;
    let path = &location.path;
    let m = fs::symlink_metadata(path).map_err(error)?;
    let kind = kind(path, m.is_dir(), m.is_symlink());
    let name = path
        .file_name()
        .unwrap_or(path.as_os_str())
        .to_string_lossy()
        .into_owned();
    Ok(Entry {
        location: location.clone(),
        hidden: name.starts_with('.'),
        name,
        kind,
        size: if m.is_dir() { None } else { Some(m.len()) },
        modified: Some(m.mtime()),
        link_target: if m.is_symlink() {
            Some(fs::read_link(path).map_err(error)?)
        } else {
            None
        },
        owner: Some(m.uid().to_string()),
        mode: Some(m.mode()),
        icon: icon(path, kind),
    })
}
pub(crate) fn list(location: &Location) -> Result<Vec<Entry>, FilesError> {
    validate(location)?;
    let mut entries = fs::read_dir(&location.path)
        .map_err(error)?
        .map(|e| {
            let e = e.map_err(error)?;
            info(&Location::local(e.path()))
        })
        .collect::<Result<Vec<_>, _>>()?;
    entries.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(entries)
}
pub(crate) fn remove(path: &Path) -> Result<(), FilesError> {
    if fs::symlink_metadata(path).map_err(error)?.is_dir() {
        fs::remove_dir_all(path)
    } else {
        fs::remove_file(path)
    }
    .map_err(error)
}
