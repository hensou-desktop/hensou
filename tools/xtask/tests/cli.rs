use std::process::Command;

#[test]
fn help_describes_the_available_check() {
    let output = Command::new(env!("CARGO_BIN_EXE_xtask"))
        .arg("--help")
        .output()
        .unwrap();
    assert!(output.status.success());
    assert!(
        String::from_utf8(output.stdout)
            .unwrap()
            .contains("cargo xtask")
    );
}

#[test]
fn version_identifies_the_development_tool() {
    let output = Command::new(env!("CARGO_BIN_EXE_xtask"))
        .arg("--version")
        .output()
        .unwrap();
    assert!(output.status.success());
    assert_eq!(
        String::from_utf8(output.stdout).unwrap().trim(),
        "hensou-xtask 0.1.0"
    );
}

#[test]
fn unknown_commands_fail_instead_of_silently_skipping_checks() {
    let output = Command::new(env!("CARGO_BIN_EXE_xtask"))
        .arg("unknown")
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("Unknown arguments")
    );
}
