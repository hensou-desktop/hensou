//! The existing desktop-theme file contract. I/O and watching belong to hosts.
use std::path::Path;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Appearance {
    pub name: &'static str,
    pub mode: &'static str,
    pub extra_state: &'static str,
}

impl Default for Appearance {
    fn default() -> Self {
        Self {
            name: "platinum",
            mode: "dark",
            extra_state: "off",
        }
    }
}

impl Appearance {
    /// Invalid/missing mode preserves the last usable value. Name falls back to
    /// Platinum; missing/invalid extra is off. Win98 retains but ignores extra.
    pub fn update(&self, name: Option<&str>, mode: Option<&str>, extra: Option<&str>) -> Self {
        Self {
            name: if name.map(str::trim) == Some("win98") {
                "win98"
            } else {
                "platinum"
            },
            mode: match mode.map(str::trim) {
                Some("light") => "light",
                Some("dark") => "dark",
                _ => self.mode,
            },
            extra_state: if extra.map(str::trim) == Some("on") {
                "on"
            } else {
                "off"
            },
        }
    }

    pub fn read(&self, directory: &Path) -> Self {
        let read = |name| std::fs::read_to_string(directory.join(name)).ok();
        self.update(
            read("theme-name").as_deref(),
            read("theme").as_deref(),
            read("theme-extra").as_deref(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::Appearance;

    #[test]
    fn missing_startup_is_platinum_dark_without_extra() {
        assert_eq!(
            Appearance::default().update(None, None, None),
            Appearance::default()
        );
    }

    #[test]
    fn all_five_appearances_keep_persisted_identifiers() {
        for (name, mode, extra) in [
            ("platinum", "light", "off"),
            ("platinum", "dark", "off"),
            ("platinum", "dark", "on"),
            ("win98", "light", "off"),
            ("win98", "dark", "on"),
        ] {
            let state = Appearance::default().update(Some(name), Some(mode), Some(extra));
            assert_eq!(
                (state.name, state.mode, state.extra_state),
                (name, mode, extra)
            );
        }
    }

    #[test]
    fn invalid_transient_and_missing_mode_keep_current_mode() {
        let light = Appearance::default().update(Some("win98"), Some("light"), Some("on"));
        for invalid in [None, Some(""), Some("lig"), Some("broken")] {
            assert_eq!(
                light.update(Some("unknown"), invalid, Some("invalid")),
                Appearance {
                    name: "platinum",
                    mode: "light",
                    extra_state: "off",
                }
            );
        }
    }

    #[test]
    fn whitespace_is_not_part_of_persisted_identifiers() {
        assert_eq!(
            Appearance::default().update(Some("win98\n"), Some(" light \n"), Some("on\n")),
            Appearance {
                name: "win98",
                mode: "light",
                extra_state: "on"
            }
        );
    }
}
