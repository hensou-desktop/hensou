use cxx_qt_lib::QString;

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
    // Link the same compiled QML module and native host as the real executable.
    hensou_demo::link_resources();
    let directory = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "tests/demo".into());
    let function = std::env::args().nth(2).unwrap_or_default();
    std::process::exit(ffi::run_tests(
        &QString::from(directory.as_str()),
        &QString::from(function.as_str()),
    ));
}
