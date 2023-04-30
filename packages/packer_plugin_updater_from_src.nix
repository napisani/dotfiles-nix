{ stdenv, lib, pkgs, fetchurl }:
stdenv.mkDerivation {
  name = "packer_plugin_updater";
  version = "0.1.0";
  src = pkgs.fetchFromGitHub ({
    owner = "napisani";
    repo = "packer-plugin-updater";
    rev = "186059a2a709cb06bc429ce2fc3888bd2f9cc642";
    hash = "sha256-C0fcESjysX7MvzVPKsPxNfBTrFNRIRzpejn3OfYBf34=";
  });
  buildInputs = with pkgs; [
    rustc
    cargo
    openssl.dev
    pkg-config
    libiconv
  ] ++ (if pkgs.system == "x86_64-darwin" || pkgs.system == "aarch64-darwin" then [
    darwin.apple_sdk.frameworks.Security
  ] else [ ]);
  buildPhase = ''
    cargo build --release
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp target/release/packer_plugin_updater $out/bin/packer_plugin_updater
    chmod +x $out/bin/packer_plugin_updater
    rm -rf target 
  '';
}
