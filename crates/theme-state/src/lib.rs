//! The existing desktop-theme file contract. I/O and watching belong to hosts.
use std::path::Path;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Appearance {
    pub name: &'static str,
    pub appearance: &'static str,
    pub mode: &'static str,
    pub extra_state: &'static str,
}

impl Default for Appearance {
    fn default() -> Self {
        Self {
            name: "platinum",
            appearance: "dark-grey",
            mode: "dark",
            extra_state: "off",
        }
    }
}

impl Appearance {
    /// Invalid/missing mode preserves the last usable value. Name falls back to
    /// Platinum; missing/invalid extra is off. Memphis retains but ignores extra.
    pub fn update(&self, name: Option<&str>, mode: Option<&str>, extra: Option<&str>) -> Self {
        self.update_appearance(name, mode, extra, None)
    }

    /// Resolve the appearance without writing or discarding an unknown saved ID.
    pub fn update_appearance(
        &self,
        name: Option<&str>,
        mode: Option<&str>,
        extra: Option<&str>,
        appearance: Option<&str>,
    ) -> Self {
        let mut next = Self {
            appearance: "",
            name: if name.map(str::trim) == Some("memphis") {
                "memphis"
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
        };
        let fallback = if next.mode == "dark" {
            "dark-grey"
        } else if next.name == "memphis" {
            "standard"
        } else {
            "light"
        };
        next.appearance = match appearance.map(str::trim) {
            Some("dark-grey") => "dark-grey",
            Some("light") if next.name == "platinum" => "light",
            Some("drawing-board") if next.name == "platinum" => "drawing-board",
            Some(id) if next.name == "memphis" => match id {
                "standard" => "standard",
                "brick" => "brick",
                "desert" => "desert",
                "eggplant" => "eggplant",
                "lilac" => "lilac",
                "maple" => "maple",
                "marine" => "marine",
                "plum" => "plum",
                "pumpkin" => "pumpkin",
                "rainy-day" => "rainy-day",
                "red-white-blue" => "red-white-blue",
                "rose" => "rose",
                "slate" => "slate",
                "spruce" => "spruce",
                "storm" => "storm",
                "teal" => "teal",
                "wheat" => "wheat",
                "high-contrast-black" => "high-contrast-black",
                "high-contrast-white" => "high-contrast-white",
                "high-contrast-1" => "high-contrast-1",
                "high-contrast-2" => "high-contrast-2",
                _ => fallback,
            },
            _ => fallback,
        };
        next.mode = match next.appearance {
            "dark-grey" | "high-contrast-black" | "high-contrast-1" | "high-contrast-2" => "dark",
            _ => "light",
        };
        next
    }

    pub fn read(&self, directory: &Path) -> Self {
        let read = |name| std::fs::read_to_string(directory.join(name)).ok();
        self.update_appearance(
            read("theme-name").as_deref(),
            read("theme").as_deref(),
            read("theme-extra").as_deref(),
            read("theme-appearance").as_deref(),
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
            ("memphis", "light", "off"),
            ("memphis", "dark", "on"),
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
        let light = Appearance::default().update(Some("memphis"), Some("light"), Some("on"));
        for invalid in [None, Some(""), Some("lig"), Some("broken")] {
            assert_eq!(
                light.update(Some("unknown"), invalid, Some("invalid")),
                Appearance {
                    name: "platinum",
                    appearance: "light",
                    mode: "light",
                    extra_state: "off",
                }
            );
        }
    }

    #[test]
    fn whitespace_is_not_part_of_persisted_identifiers() {
        assert_eq!(
            Appearance::default().update(Some("memphis\n"), Some(" light \n"), Some("on\n")),
            Appearance {
                name: "memphis",
                appearance: "standard",
                mode: "light",
                extra_state: "on"
            }
        );
    }
}

#[cfg(test)]
mod migration_tests {
    use super::Appearance;

    #[test]
    fn old_files_and_unknown_ids_resolve_without_overwriting_preferences() {
        let dir = std::env::temp_dir().join(format!("hensou-appearance-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        for (name, mode, expected) in [
            ("memphis", "light", "standard"),
            ("memphis", "dark", "dark-grey"),
            ("platinum", "light", "light"),
            ("platinum", "dark", "dark-grey"),
        ] {
            std::fs::write(dir.join("theme-name"), name).unwrap();
            std::fs::write(dir.join("theme"), mode).unwrap();
            assert_eq!(Appearance::default().read(&dir).appearance, expected);
            std::fs::write(dir.join("theme-appearance"), "future-scheme").unwrap();
            assert_eq!(Appearance::default().read(&dir).appearance, expected);
            assert_eq!(
                std::fs::read_to_string(dir.join("theme-appearance")).unwrap(),
                "future-scheme"
            );
            std::fs::remove_file(dir.join("theme-appearance")).unwrap();
        }
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn appearance_derives_mode_and_keeps_extra_dark_preference() {
        for (name, id, mode) in [
            ("memphis", "brick", "light"),
            ("memphis", "high-contrast-1", "dark"),
            ("memphis", "high-contrast-2", "dark"),
            ("memphis", "high-contrast-black", "dark"),
            ("memphis", "high-contrast-white", "light"),
            ("platinum", "drawing-board", "light"),
        ] {
            let state = Appearance::default().update_appearance(
                Some(name),
                Some("dark"),
                Some("on"),
                Some(id),
            );
            assert_eq!(
                (state.appearance, state.mode, state.extra_state),
                (id, mode, "on")
            );
        }
    }
}
