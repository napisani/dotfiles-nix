# Activation code must come from the evaluated generation, not a different
# branch of the live dotfiles checkout. Keep Node's relative require layout.
{ lib }:
lib.cleanSourceWith {
  src = ./dotfiles;
  name = "native-install-scripts";
  filter =
    path: type:
    let
      relative = lib.removePrefix (toString ./dotfiles + "/") (toString path);
    in
    builtins.elem relative [
      "agents"
      "agents/scripts"
      "scripts"
      "scripts/lib"
    ]
    || (
      type == "regular"
      && (lib.hasPrefix "agents/scripts/" relative || lib.hasPrefix "scripts/lib/" relative)
      && (lib.hasSuffix ".js" relative || lib.hasSuffix ".py" relative)
    );
}
