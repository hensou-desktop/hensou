use hensou_file_icons::ThemeIcons;
use hensou_files_model::{
    IconHint,
    platform::{GenericKind, IconResolver, ResolvedIcon, ThemeId},
};
#[test]
fn theme_chain_excludes_modern_art_and_falls_back() {
    let dir = tempfile::tempdir().unwrap();
    for theme in ["Mountainous-platinum", "Period", "hicolor", "Adwaita"] {
        std::fs::create_dir_all(dir.path().join(theme).join("32x32/mimetypes")).unwrap();
    }
    std::fs::write(
        dir.path().join("Mountainous-platinum/index.theme"),
        "[Icon Theme]\nInherits=Period,hicolor,Adwaita\nDirectories=32x32/mimetypes\n",
    )
    .unwrap();
    std::fs::write(
        dir.path().join("Period/index.theme"),
        "[Icon Theme]\nDirectories=32x32/mimetypes\n",
    )
    .unwrap();
    for (theme, name) in [
        ("Period", "hensou-kind-text"),
        ("hicolor", "editor"),
        ("Adwaita", "text-plain"),
    ] {
        std::fs::write(
            dir.path()
                .join(theme)
                .join(format!("32x32/mimetypes/{name}.svg")),
            "<svg/>",
        )
        .unwrap();
    }
    let resolver = ThemeIcons::new(vec![dir.path().into()]);
    let mut hint = IconHint {
        name: "text/plain".into(),
        launcher_icon: None,
        launcher_name: None,
    };
    assert!(
        matches!(resolver.resolve(ThemeId::Platinum, &hint, 32), ResolvedIcon::Generic(GenericKind::Text, path) if path.starts_with(dir.path().join("Period")))
    );
    hint.launcher_icon = Some("editor".into());
    hint.launcher_name = Some("Editor".into());
    assert!(matches!(
        resolver.resolve(ThemeId::Platinum, &hint, 32),
        ResolvedIcon::Lettermark { letter: 'E', .. }
    ));
}
#[test]
fn exact_active_art_wins_and_every_mime_kind_has_period_fallback() {
    let dir = tempfile::tempdir().unwrap();
    let theme = dir.path().join("Mountainous-win98");
    std::fs::create_dir_all(theme.join("32x32/mimetypes")).unwrap();
    std::fs::write(
        theme.join("index.theme"),
        "[Icon Theme]\nInherits=hicolor,Adwaita\nDirectories=32x32/mimetypes\n",
    )
    .unwrap();
    let resolver = ThemeIcons::new(vec![dir.path().into()]);
    for (mime, name, kind) in [
        ("unknown/type", "document", GenericKind::Document),
        ("text/plain", "text", GenericKind::Text),
        ("image/png", "image", GenericKind::Image),
        ("audio/flac", "audio", GenericKind::Audio),
        ("video/mp4", "video", GenericKind::Video),
        ("application/zip", "archive", GenericKind::Archive),
        (
            "application/x-executable",
            "application",
            GenericKind::Application,
        ),
        ("inode/directory", "folder", GenericKind::Folder),
    ] {
        let path = theme.join(format!("32x32/mimetypes/hensou-kind-{name}.png"));
        std::fs::write(&path, b"fixture").unwrap();
        let hint = IconHint {
            name: mime.into(),
            launcher_icon: None,
            launcher_name: None,
        };
        assert_eq!(
            resolver.resolve(ThemeId::Memphis, &hint, 32),
            ResolvedIcon::Generic(kind, path)
        );
    }
    let exact = theme.join("32x32/mimetypes/text-plain.svg");
    std::fs::write(&exact, "<svg/>").unwrap();
    let hint = IconHint {
        name: "text/plain".into(),
        launcher_icon: None,
        launcher_name: None,
    };
    assert_eq!(
        resolver.resolve(ThemeId::Memphis, &hint, 32),
        ResolvedIcon::Themed(exact)
    );
}
