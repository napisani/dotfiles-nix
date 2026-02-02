{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
  zlib,
}:

let
  version = "2026.01.23-916f423";

  sourcesBySystem = {
    "aarch64-darwin" = {
      os = "darwin";
      arch = "arm64";
      sha256 = "vTOszoUW4LWUHlKwwexQRH1Uy5CcvN3el6y1jRfBCeM=";
    };
    "x86_64-darwin" = {
      os = "darwin";
      arch = "x64";
      sha256 = "MuRxnITcZl2JphP+vcqRZo1JTr9mSTNjZKs3DPvxsE0=";
    };
    "aarch64-linux" = {
      os = "linux";
      arch = "arm64";
      sha256 = "1y2IBypnoCHWFmYrmGxp49oXmMew+fBffBKiorWsJ/E=";
    };
    "x86_64-linux" = {
      os = "linux";
      arch = "x64";
      sha256 = "XfN1Fm1Rvo6GDRVtyzRV/+mkSZuJbp8dEoOn8pH1RnQ=";
    };
  };

  inherit (stdenv.hostPlatform) system;

  sourceInfo =
    sourcesBySystem.${system} or (throw ''
      cursor-agent: unsupported system "${system}".
      Supported systems: ${lib.concatStringsSep ", " (builtins.attrNames sourcesBySystem)}
    '');

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${version}/${sourceInfo.os}/${sourceInfo.arch}/agent-cli-package.tar.gz";
    inherit (sourceInfo) sha256;
  };

  linuxLibs =
    if stdenv.isLinux then
      [
        stdenv.cc.cc
        stdenv.cc.libc
        openssl
        zlib
      ]
    else
      [ ];
in
stdenv.mkDerivation rec {
  pname = "cursor-agent";
  inherit version src;

  dontUnpack = true;

  nativeBuildInputs = if stdenv.isLinux then [ autoPatchelfHook ] else [ ];
  buildInputs = linuxLibs;

  installPhase = ''
    runHook preInstall

    dest="$out/share/${pname}/${version}"
    mkdir -p "$dest" "$out/bin"

    tar -xzf "$src" -C "$dest"

    ln -s "$dest/cursor-agent" "$out/bin/cursor-agent"
    ln -s "$dest/cursor-agent" "$out/bin/agent"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Cursor Agent CLI";
    homepage = "https://cursor.com";
    license = licenses.unfree;
    mainProgram = "cursor-agent";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
