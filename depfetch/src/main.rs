use std::process::Command;
use std::path::Path;

const LUA_URL: &str = "https://www.lua.org/ftp/lua-5.4.8.tar.gz";
const SOLOUD_URL: &str = "https://solhsa.com/soloud/soloud_20200207_lite.zip";

fn main() {
    let external = Path::new("../external");
    
    let _ = Command::new("git")
        .args(["submodule", "update", "--init", "--recursive"])
        .current_dir("..")
        .status();

    if !external.join("lua-5.4.8").exists() {
        let _ = Command::new("sh")
            .args(["-c", &format!("curl -sL {} | tar xz -C {}", LUA_URL, external.display())])
            .status();
    }
    
    if !external.join("soloud20200207").exists() {
        let _ = Command::new("sh")
            .args(["-c", &format!("curl -sL {} -o /tmp/soloud.zip && unzip -q -o /tmp/soloud.zip -d {}", SOLOUD_URL, external.display())])
            .status();
    }
}