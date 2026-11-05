use cxx_qt_lib::QString;
use hensou_files::scenario::{FixtureScenario, ScenarioOptions};
use std::sync::Arc;

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("test_runner.h");
        fn run_tests(directory: &QString, function: &QString) -> i32;
    }
}

fn main() {
    // The same compiled QML module and native code as the executable, wired
    // to the fixture service through the production seam.
    hensou_files::link_resources();
    hensou_files::bridge::install(Arc::new(FixtureScenario::with_fixtures(
        ScenarioOptions::from_env(),
    )));
    let directory = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "tests/files".into());
    let function = std::env::args().nth(2).unwrap_or_default();
    std::process::exit(ffi::run_tests(
        &QString::from(directory.as_str()),
        &QString::from(function.as_str()),
    ));
}
