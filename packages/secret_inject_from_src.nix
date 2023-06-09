{ stdenv, lib, pkgs, fetchurl }:
stdenv.mkDerivation {
  name = "secret_inject";
  version = "0.1.1";
  src = pkgs.fetchFromGitHub({
    owner = "napisani";
    repo = "secret_inject";
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
    cp target/release/secret_inject $out/bin/secret_inject
    chmod +x $out/bin/secret_inject
    rm -rf target 
  '';
}
