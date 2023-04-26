{ stdenv, lib, pkgs, fetchurl }:
stdenv.mkDerivation {
  name = "secret_inject";
  version = "0.1.1";
  src = pkgs.fetchFromGitHub({
    owner = "napisani";
    repo = "secret_inject";
    rev = "13a1f3fcd2ca1a773c62d1ffa74f7b02bb419479";
  });

  buildCommand = ''
    cargo build --release
    cp target/release/secret_inject $out/bin/secret_inject
    chmod +x $out/bin/secret_inject
    rm -rf target 
  '';
}
