{ stdenv, lib, pkgs, fetchurl }:
stdenv.mkDerivation {
  name = "secret_inject";
  version = "0.1.1";
  src = fetchurl { 
     url = "https://github.com/napisani/secret_inject/releases/download/v0.1.1/secret_inject-v0.1.1-x86_64-apple-darwin.tar.xz";
     hash = "sha256-F4RaJnt2+g4jKlhWfk1W3IUuyUVqV+Cz/U97ItAPDUU=";
  };
  buildCommand = ''
    cargo build --release
    cp target/release/secret_inject $out/bin/secret_inject
    chmod +x $out/bin/secret_inject
    rm -rf target 
  '';
}
