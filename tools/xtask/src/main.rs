use std::env;
use std::io;
use std::process::{Command, ExitCode};

const HELP: &str = "Hensou workspace checks

Usage: cargo xtask [check|--help|--version]

check runs formatting, Clippy and all workspace tests.
";

fn check() -> io::Result<ExitCode> {
    let checks: &[&[&str]] = &[
        &["fmt", "--all", "--", "--check"],
        &[
            "clippy",
            "--workspace",
            "--all-targets",
            "--locked",
            "--",
            "-D",
            "warnings",
        ],
        &["test", "--workspace", "--locked"],
    ];
    // Cargo supplies the executable path when this command is run by the alias.
    let cargo = env::var_os("CARGO").unwrap_or_else(|| "cargo".into());
    for args in checks {
        eprintln!("Running cargo {}", args.join(" "));
        if !Command::new(&cargo).args(*args).status()?.success() {
            return Ok(ExitCode::FAILURE);
        }
    }
    Ok(ExitCode::SUCCESS)
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    match args.as_slice() {
        [] => {
            print!("{HELP}");
            ExitCode::SUCCESS
        }
        [arg] if arg == "--help" || arg == "-h" => {
            print!("{HELP}");
            ExitCode::SUCCESS
        }
        [arg] if arg == "--version" => {
            println!("hensou-xtask {}", env!("CARGO_PKG_VERSION"));
            ExitCode::SUCCESS
        }
        [arg] if arg == "check" => match check() {
            Ok(code) => code,
            Err(error) => {
                eprintln!("Cannot run workspace checks: {error}");
                ExitCode::FAILURE
            }
        },
        _ => {
            eprintln!(
                "Unknown arguments.

{HELP}"
            );
            ExitCode::from(2)
        }
    }
}
