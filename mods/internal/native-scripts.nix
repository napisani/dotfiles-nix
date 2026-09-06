# Activation code must come from the evaluated generation, not a different
# branch of the live dotfiles checkout. Keep Node's relative require layout.
{ lib }:
lib.cleanSourceWith {
  src = ./.;
  name = "native-install-scripts";
  filter =
    path: type:
    let
      relative = lib.removePrefix (toString ./. + "/") (toString path);
    in
    builtins.elem relative [
      "agents"
      "agents/scripts"
      "npm"
      "npm/scripts"
      "uv"
      "uv/scripts"
      "model-runtimes"
      "model-runtimes/scripts"
      "scripts"
      "scripts/lib"
    ]
    || (
      type == "regular"
      && lib.any (prefix: lib.hasPrefix prefix relative) [
        "agents/scripts/"
        "npm/scripts/"
        "uv/scripts/"
        "model-runtimes/scripts/"
        "scripts/"
      ]
      && (lib.hasSuffix ".js" relative || lib.hasSuffix ".py" relative)
    );
}
