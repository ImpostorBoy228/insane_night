use std::process::Command;
use std::env;
use std::fs;

fn main() {
    let current_exe = env::current_exe().expect("failed to get current exe");
    let project_root = current_exe
        .parent().unwrap()
        .parent().unwrap()
        .parent().unwrap()
        .parent().unwrap();

    // git submodules
    let status = Command::new("git")
        .args(["submodule", "update", "--init", "--recursive"])
        .current_dir(&project_root)
        .status();
    if !status.map_or(false, |s| s.success()) {
        eprintln!("git submodule update failed");
    }

    // Check if bgfx libraries need to be built
    let lib_dir = project_root.join("external/lib");
    let libbgfx = lib_dir.join("libbgfx.a");
    
    if libbgfx.exists() {
        eprintln!("bgfx libraries already built");
        return;
    }

    // Build bgfx via its root makefile
    let bgfx_dir = project_root.join("external/bgfx");
    
    // First generate the build files if needed
    let build_projects = bgfx_dir.join(".build/projects/gmake-linux-gcc");
    if !build_projects.exists() {
        let genie = project_root.join("external/bx/tools/bin/linux/genie");
        let genie_path = fs::canonicalize(&genie).expect("genie not found");
        
        let status = Command::new(&genie_path)
            .args(["--cc=gcc", "--gcc=linux-gcc", "--with-tools", "gmake"])
            .current_dir(&bgfx_dir)
            .status();
        
        if !status.map_or(false, |s| s.success()) {
            eprintln!("genie failed to generate project files");
        }
    }
    
    // Build bgfx, bx, bimg
    let status = Command::new("make")
        .args([
            "-C", build_projects.to_str().unwrap(),
            "config=release64", "-j2", "bgfx", "bx", "bimg"
        ])
        .status();
    
    if !status.map_or(false, |s| s.success()) {
        eprintln!("make bgfx/bx/bimg failed");
    }

    // Also build shaderc
    let status = Command::new("make")
        .args([
            "-C", build_projects.to_str().unwrap(),
            "config=release64", "-j2", "shaderc"
        ])
        .status();

    if !status.map_or(false, |s| s.success()) {
        eprintln!("make shaderc failed");
    }

    // Create lib directory and copy libraries
    fs::create_dir_all(&lib_dir).ok();
    
    let bin_dir = bgfx_dir.join(".build/linux64_gcc/bin");
    if bin_dir.exists() {
        let _ = Command::new("cp")
            .args([bin_dir.join("libbgfxRelease.a"), lib_dir.join("libbgfx.a")])
            .status();
        let _ = Command::new("cp")
            .args([bin_dir.join("libbimgRelease.a"), lib_dir.join("libbimg.a")])
            .status();
        let _ = Command::new("cp")
            .args([bin_dir.join("libbxRelease.a"), lib_dir.join("libbx.a")])
            .status();
        // Copy shaderc
        let _ = Command::new("cp")
            .args([bin_dir.join("shadercRelease"), bgfx_dir.join("tools/bin/linux/shaderc")])
            .status();
        eprintln!("bgfx, bx, bimg built and installed");
    }
}