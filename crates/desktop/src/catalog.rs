use crate::*;
use std::os::unix::fs::MetadataExt;
#[derive(Clone)]
pub(crate) struct Item { pub icon: DesktopIcon, pub location: Location, pub size: Option<u64>, pub date: Option<i64> }
impl DesktopProvider {
    pub(crate) fn catalog(&self, theme: Theme) -> Result<Vec<Item>, FilesError> {
        let memphis = theme == Theme::Memphis;
        let mut items = vec![
            self.item(theme, "computer", IconKind::Computer, if memphis { "My Computer" } else { &self.config.hostname }, "computer", Location::virtual_place(Place::Computer)),
            self.item(theme, "ssh-hosts", IconKind::SshHosts, if memphis { "Network Neighborhood" } else { "SSH Hosts" }, "folder", Location::virtual_place(Place::SshHosts)),
            self.item(theme, "trash", IconKind::Trash, if memphis { "Recycle Bin" } else { "Trash" }, "user-trash", Location::virtual_place(Place::Trash)),
        ];
        items[2].icon.full = Some(!self.trash.items()?.is_empty());
        if !memphis { for volume in self.volumes.volumes() { if let Some(path) = volume.mount_point { let mut item = self.item(theme, &format!("volume:{}", volume.id), IconKind::Volume, &volume.label, "drive-removable-media", Location::local(path)); item.icon.ejectable = Some(volume.removable); item.size = volume.size; items.push(item); } } }
        let mut entries = std::fs::read_dir(&self.config.desktop_dir).map_err(io_error)?.collect::<Result<Vec<_>, _>>().map_err(io_error)?;
        entries.sort_by_key(|e| e.file_name());
        for entry in entries {
            let name = entry.file_name().to_string_lossy().into_owned(); if name.starts_with('.') { continue; }
            let path = entry.path(); let metadata = std::fs::symlink_metadata(&path).map_err(io_error)?;
            let kind = if metadata.is_symlink() { IconKind::Alias } else if metadata.is_dir() { IconKind::Folder } else if path.extension().is_some_and(|e| e == "desktop") { IconKind::Launcher } else { IconKind::File };
            let hint = if kind == IconKind::Folder { "folder" } else { match path.extension().and_then(|e| e.to_str()).unwrap_or("") { "txt" | "md" | "rs" | "log" => "text/plain", "png" | "jpg" | "svg" => "image", "mp3" | "flac" | "wav" => "audio", "mp4" | "mkv" => "video", "zip" | "gz" | "xz" | "tar" => "application/zip", _ => "document" } };
            let mut item = self.item(theme, &format!("file:{name}"), kind, &name, hint, Location::local(&path));
            if kind == IconKind::Launcher {
                let text = std::fs::read_to_string(path).map_err(io_error)?; let mut in_entry = false; let mut icon = None;
                for line in text.lines() { if line.starts_with('[') { in_entry = line == "[Desktop Entry]"; } else if in_entry { if let Some(value) = line.strip_prefix("Name=") { item.icon.label = value.into(); } if let Some(value) = line.strip_prefix("Icon=") { icon = Some(value.into()); } } }
                item.icon.art = self.art(theme, IconHint { name: "application".into(), launcher_icon: Some(icon.unwrap_or_default()), launcher_name: Some(item.icon.label.clone()) });
            }
            item.size = Some(metadata.len()); item.date = Some(metadata.mtime()); items.push(item);
        }
        Ok(items)
    }
    fn item(&self, theme: Theme, id: &str, kind: IconKind, label: &str, hint: &str, location: Location) -> Item {
        Item { icon: DesktopIcon { id: id.into(), kind, label: label.into(), art: self.art(theme, IconHint { name: hint.into(), launcher_icon: None, launcher_name: None }), position: Point { x: 0, y: 0 }, available: true, reason: None, full: None, ejectable: None }, location, size: None, date: None }
    }
    fn art(&self, theme: Theme, hint: IconHint) -> IconArt { match self.icons.resolve(if theme == Theme::Memphis { ThemeId::Memphis } else { ThemeId::Platinum }, &hint, 32) { ResolvedIcon::Themed(path) => IconArt::Themed { path }, ResolvedIcon::Generic(kind, path) => IconArt::Generic { kind: format!("{kind:?}").to_lowercase(), path }, ResolvedIcon::Lettermark { letter, tint } => IconArt::Lettermark { letter, tint } } }
}
