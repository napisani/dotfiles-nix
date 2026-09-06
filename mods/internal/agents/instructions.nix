# Only Home Manager writes these instruction files. Compose the shared source
# and native references once, so repeat switches do not rewrite or re-patch them.
{ lib, ... }:
{
  mkInstructionFiles =
    {
      target,
      source,
      extraText ? "",
    }:
    lib.optionalAttrs (source != null) {
      ${target} = {
        text = builtins.readFile source + extraText;
        force = true; # migrate the previously activation-written file safely
      };
    };
}
