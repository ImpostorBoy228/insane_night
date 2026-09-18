use std::process::Command;
use std::env;

fn main() {
    let current_exe = env::current_exe().expect("failed to get current exe");
    let project_root = current_exe
        .parent().unwrap()  // target/release
        .parent().unwrap()  // target
        .parent().unwrap()  // depfetch
        .parent().unwrap(); // insane_night

    let status = Command::new("git")
        .args(["submodule", "update", "--init", "--recursive"])
        .current_dir(&project_root)
        .status();
    if !status.map_or(false, |s| s.success()) {
        eprintln!("git submodule update failed");
    }
}