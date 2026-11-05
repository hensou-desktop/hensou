//! Resolve only period theme art, never the desktop's modern fallback themes.
use hensou_files_model::{IconHint, platform::{GenericKind, IconResolver, ResolvedIcon, ThemeId}};
use std::{collections::HashSet, path::{Path, PathBuf}};

pub struct ThemeIcons { roots: Vec<PathBuf> }
impl ThemeIcons {
    /// Roots contain theme directories (the XDG `icons` directories).
    pub fn new(roots: Vec<PathBuf>) -> Self { Self { roots } }
    pub fn from_env() -> Self {
        let mut roots = Vec::new();
        if let Some(data) = std::env::var_os("XDG_DATA_HOME").map(PathBuf::from).or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/share"))) { roots.push(data.join("icons")); }
        roots.extend(std::env::split_paths(&std::env::var_os("XDG_DATA_DIRS").unwrap_or_else(|| "/usr/local/share:/usr/share".into())).map(|p| p.join("icons")));
        Self::new(roots)
    }
    fn find(&self, theme: &str, name: &str, size: u32, visited: &mut HashSet<String>) -> Option<PathBuf> {
        if matches!(theme.to_ascii_lowercase().as_str(), "adwaita" | "hicolor") || !safe_name(theme) || !safe_name(name) || !visited.insert(theme.into()) { return None; }
        let mut parents = Vec::new();
        for root in &self.roots {
            let base = root.join(theme);
            let index = std::fs::read_to_string(base.join("index.theme")).unwrap_or_default();
            let mut dirs = Vec::new();
            for line in index.lines() {
                if let Some(value) = line.strip_prefix("Inherits=") { parents.extend(value.split(',').map(str::trim).map(String::from)); }
                if let Some(value) = line.strip_prefix("Directories=").or_else(|| line.strip_prefix("ScaledDirectories=")) { dirs.extend(value.split(',').map(str::trim).map(String::from)); }
            }
            dirs.sort_by_key(|d| { let n = d.split('x').next().and_then(|s| s.parse::<u32>().ok()).unwrap_or(size); n.abs_diff(size) });
            dirs.push(String::new());
            for directory in dirs {
                if Path::new(&directory).components().any(|c| matches!(c, std::path::Component::ParentDir | std::path::Component::RootDir)) { continue; }
                for ext in ["svg", "png", "xpm"] {
                    let path = base.join(&directory).join(format!("{name}.{ext}"));
                    if path.is_file() {
                        // A theme may alias art; do not allow a symlink into forbidden sets.
                        if let Ok(real) = path.canonicalize() {
                            if !real.components().any(|c| matches!(c.as_os_str().to_str(), Some("hicolor" | "Adwaita"))) { return Some(path); }
                        }
                    }
                }
            }
        }
        parents.into_iter().find_map(|p| self.find(&p, name, size, visited))
    }
}
fn safe_name(s: &str) -> bool { !s.is_empty() && s != "." && s != ".." && !s.contains('/') }
pub fn generic_kind(name: &str) -> GenericKind {
    if name == "folder" || name == "inode/directory" { GenericKind::Folder }
    else if name.starts_with("text") { GenericKind::Text }
    else if name.starts_with("image") { GenericKind::Image }
    else if name.starts_with("audio") { GenericKind::Audio }
    else if name.starts_with("video") { GenericKind::Video }
    else if ["zip", "tar", "gzip", "bzip", "xz", "7z", "rar", "compressed"].iter().any(|s| name.contains(s)) { GenericKind::Archive }
    else if name.contains("executable") || name == "application" { GenericKind::Application }
    else { GenericKind::Document }
}
pub fn kind_name(kind: GenericKind) -> &'static str { match kind { GenericKind::Document => "document", GenericKind::Text => "text", GenericKind::Image => "image", GenericKind::Audio => "audio", GenericKind::Video => "video", GenericKind::Archive => "archive", GenericKind::Application => "application", GenericKind::Folder => "folder" } }
impl IconResolver for ThemeIcons {
    fn resolve(&self, theme: ThemeId, hint: &IconHint, size: u32) -> ResolvedIcon {
        let theme = match theme { ThemeId::Platinum => "Mountainous-platinum", ThemeId::Memphis => "Mountainous-win98" };
        let exact = hint.launcher_icon.as_deref().unwrap_or(&hint.name).replace('/', "-");
        if let Some(path) = self.find(theme, &exact, size, &mut HashSet::new()) { return ResolvedIcon::Themed(path); }
        let label = hint.launcher_name.as_deref().unwrap_or_else(|| hint.name.rsplit('/').next().unwrap_or(&hint.name));
        if hint.launcher_icon.is_none() {
            let kind = generic_kind(&hint.name);
            if let Some(path) = self.find(theme, &format!("hensou-kind-{}", kind_name(kind)), size, &mut HashSet::new()) { return ResolvedIcon::Generic(kind, path); }
        }
        // Stable FNV-1a rather than RandomState, so tiles survive restarts.
        let hash = label.bytes().fold(2166136261u32, |hash, b| (hash ^ u32::from(b)).wrapping_mul(16777619));
        ResolvedIcon::Lettermark { letter: label.chars().next().unwrap_or('?').to_uppercase().next().unwrap_or('?'), tint: format!("#{:06x}", hash & 0x7f7f7f | 0x404040) }
    }
}
