use std::path::PathBuf;
use std::pin::Pin;

use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use hensou_theme_state::Appearance;

// cxx-qt generates the audited C++ boundary. No handwritten unsafe Rust.
#[cxx_qt::bridge]
pub mod qml {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        type QQmlApplicationEngine = cxx_qt_lib::QQmlApplicationEngine;
        include!("window_metrics.h");
        #[namespace = "hensou"]
        fn watch_theme(theme: Pin<&mut HostTheme>, path: &QString);
        #[namespace = "hensou"]
        fn engine_has_roots(engine: &QQmlApplicationEngine) -> bool;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, name)]
        #[qproperty(QString, mode)]
        #[qproperty(QString, extra_state, cxx_name = "extraState")]
        type HostTheme = super::HostThemeRust;

        #[qinvokable]
        fn reload(self: Pin<&mut HostTheme>);
    }

    impl cxx_qt::Initialize for HostTheme {}
}

pub struct HostThemeRust {
    name: QString,
    mode: QString,
    extra_state: QString,
    directory: PathBuf,
    appearance: Appearance,
}

impl Default for HostThemeRust {
    fn default() -> Self {
        let base = std::env::var_os("XDG_STATE_HOME")
            .filter(|v| !v.is_empty())
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
            });
        Self {
            name: QString::from("platinum"),
            mode: QString::from("dark"),
            extra_state: QString::from("off"),
            directory: base.join("mountainous"),
            appearance: Appearance::default(),
        }
    }
}

impl qml::HostTheme {
    pub fn reload(mut self: Pin<&mut Self>) {
        let next = self.rust().appearance.read(&self.rust().directory);
        self.as_mut().set_name(QString::from(next.name));
        self.as_mut().set_mode(QString::from(next.mode));
        self.as_mut()
            .set_extra_state(QString::from(next.extra_state));
        self.rust_mut().appearance = next;
    }
}

impl cxx_qt::Initialize for qml::HostTheme {
    fn initialize(mut self: Pin<&mut Self>) {
        self.as_mut().reload();
        let directory = QString::from(self.rust().directory.to_string_lossy().as_ref());
        qml::watch_theme(self, &directory);
    }
}
