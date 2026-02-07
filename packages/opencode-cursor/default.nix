{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  runCommand,
  bun,
  nodejs,
}:

let
  srcBase = fetchFromGitHub {
    owner = "Nomadcxx";
    repo = "opencode-cursor";
    rev = "d612581f704813c61e14110e7f1111ee39d44c5d";
    hash = "sha256-lpRMbm7Am4zjMslXwgncGJbyx72kNJMwNvbiEk2Xht8=";
  };

  src = runCommand "opencode-cursor-src" { } ''
    mkdir -p "$out"
    cp -R ${srcBase}/* "$out/"
    cp ${./package-lock.json} "$out/package-lock.json"
  '';

  npmLock = "${src}/package-lock.json";
in
buildNpmPackage rec {
  pname = "opencode-cursor";
  version = "2.0.1";

  inherit src;

  npmDeps = fetchNpmDeps {
    inherit src npmLock;
    hash = "sha256-kErW9YYbgaGbdW9+iSnvt2e1ZPEbIABfQkM6bSJuOvU=";
  };

  nativeBuildInputs = [
    bun
    nodejs
  ];

  npmInstallFlags = [ "--offline" ];

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/opencode/plugins"
    cp dist/index.js "$out/share/opencode/plugins/cursor-acp.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode cursor-acp plugin";
    homepage = "https://github.com/Nomadcxx/opencode-cursor";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
