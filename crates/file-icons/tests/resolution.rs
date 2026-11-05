use hensou_file_icons::ThemeIcons;
use hensou_files_model::{IconHint, platform::{IconResolver, ThemeId, ResolvedIcon, GenericKind}};
#[test]
fn theme_chain_excludes_modern_art_and_falls_back() {
    let dir = tempfile::tempdir().unwrap();
    for theme in ["Mountainous-platinum", "Period", "hicolor", "Adwaita"] {
        std::fs::create_dir_all(dir.path().join(theme).join("32x32/mimetypes")).unwrap();
    }
    std::fs::write(dir.path().join("Mountainous-platinum/index.theme"), "[Icon Theme]\nInherits=Period,hicolor,Adwaita\nDirectories=32x32/mimetypes\n").unwrap();
    std::fs::write(dir.path().join("Period/index.theme"), "[Icon Theme]\nDirectories=32x32/mimetypes\n").unwrap();
    for (theme, name) in [("Period", "hensou-kind-text"), ("hicolor", "editor"), ("Adwaita", "text-plain")] {
        std::fs::write(dir.path().join(theme).join(format!("32x32/mimetypes/{name}.svg")), "<svg/>").unwrap();
    }
    let resolver = ThemeIcons::new(vec![dir.path().into()]);
    let mut hint = IconHint { name: "text/plain".into(), launcher_icon: None, launcher_name: None };
    assert!(matches!(resolver.resolve(ThemeId::Platinum, &hint, 32), ResolvedIcon::Generic(GenericKind::Text, path) if path.starts_with(dir.path().join("Period"))));
    hint.launcher_icon = Some("editor".into()); hint.launcher_name = Some("Editor".into());
    assert!(matches!(resolver.resolve(ThemeId::Platinum, &hint, 32), ResolvedIcon::Lettermark { letter: 'E', .. }));
}
