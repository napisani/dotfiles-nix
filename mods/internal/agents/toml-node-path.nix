# @iarna/toml is an activation runtime dependency, not a mutable CLI install.
# Reuse the checked-in npm lock's URL/integrity; it has no dependencies.
{ pkgs }:
let
  lock = builtins.fromJSON (builtins.readFile ./scripts/package-lock.json);
  package = lock.packages."node_modules/@iarna/toml";
  dependency = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-toml";
    version = package.version;
    src = pkgs.fetchurl {
      url = package.resolved;
      hash = package.integrity;
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p "$out/node_modules/@iarna/toml"
      cp -R . "$out/node_modules/@iarna/toml/"
    '';
  };
in
"${dependency}/node_modules"
