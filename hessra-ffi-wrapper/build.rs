use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    // Instead of generating headers with cbindgen, we'll find and copy the pre-generated
    // header file from the hessra-ffi crate.

    // Get the output directory for the header file
    let out_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let include_dir = PathBuf::from(&out_dir).join("include");

    // Create the include directory if it doesn't exist
    fs::create_dir_all(&include_dir).expect("Failed to create include directory");

    // Find the location of the hessra-ffi crate in the dependency tree
    let output = std::process::Command::new("cargo")
        .args(["metadata", "--format-version=1"])
        .output()
        .expect("Failed to execute cargo metadata");

    let metadata: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("Failed to parse cargo metadata");

    // Find the hessra-ffi package in the dependency graph
    let packages = metadata["packages"]
        .as_array()
        .expect("Expected packages array");
    let hessra_ffi_pkg = packages
        .iter()
        .find(|pkg| pkg["name"].as_str().unwrap_or("") == "hessra-ffi")
        .expect("Could not find hessra-ffi package in dependencies");

    // Get the manifest path of the hessra-ffi crate
    let manifest_path = hessra_ffi_pkg["manifest_path"]
        .as_str()
        .expect("No manifest_path");
    let manifest_path_buf = PathBuf::from(manifest_path);
    let hessra_ffi_dir = manifest_path_buf.parent().unwrap();

    // Path to the pre-generated hessra_ffi.h file
    let source_header = hessra_ffi_dir.join("hessra_ffi.h");
    let dest_header = include_dir.join("hessra_ffi.h");

    // Copy the header file to our include directory
    fs::copy(&source_header, &dest_header).expect(&format!(
        "Failed to copy header from {:?} to {:?}",
        source_header, dest_header
    ));

    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed={}", source_header.display());
}
