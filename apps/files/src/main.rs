use hensou_files::{cli, instance};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let cwd = std::env::current_dir().unwrap_or_else(|_| "/".into());
    let launch = match cli::parse(&args, &cwd) {
        Ok(launch) => launch,
        Err(cli::CliError::Help) => {
            println!("{}", cli::USAGE);
            return;
        }
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(2);
        }
    };
    match instance::claim(&instance::directory(), &launch.requests) {
        // A running Files took the requests.
        Ok(instance::Claim::Forwarded) => {}
        Ok(instance::Claim::Primary(resident)) => {
            std::process::exit(hensou_files::run(launch, resident));
        }
        Err(e) => {
            eprintln!("hensou-files: cannot reach or start the resident Files: {e}");
            std::process::exit(1);
        }
    }
}
