{ stdenv, lib, pkgs, fetchurl }:
stdenv.mkDerivation {
  name = "packer_plugin_updater";
  version = "0.1.0";
  src = pkgs.fetchFromGitHub({
    owner = "napisani";
    repo = "packer_plugin_updater";
    rev = "13a1f3fcd2ca1a773c62d1ffa74f7b02bb419479";
    hash = "sha256-Uerv3Dg84jAHhySh86OZi7mgOaS3SWwWzNQcatymvqc=";
  });
  buildInputs = with pkgs; [ 
      rustc 
      cargo 
  ];
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
