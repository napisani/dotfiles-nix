# Build native RTK resources without touching user state. Adapters select the
# native flags and own target paths; this builder knows no agent identities.
# The pinned generator must work offline and emit reproducible retained files.
# When upgrading it, run checks/rtk-reproducibility.sh: a normal runCommand
# does not itself enforce reproducibility, nor does a cached runtime check.
{
  pkgs,
  lib,
  rtk,
  args,
  files,
  patch ? "",
}:
pkgs.runCommand "rtk-assets-${rtk.version}" { nativeBuildInputs = [ rtk ]; } ''
  export HOME="$TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  for file in ${lib.escapeShellArgs files}; do
    mkdir -p "$HOME/$(dirname "$file")"
  done
  rtk init -g ${lib.escapeShellArgs args} --no-trust-filters </dev/null
  mkdir -p "$out"
  # Do not retain generated scratch instructions/config: they can contain
  # the temporary HOME path and are not part of an adapter's owned resources.
  for file in ${lib.escapeShellArgs files}; do
    mkdir -p "$out/$(dirname "$file")"
    cp "$HOME/$file" "$out/$file"
  done
  ${patch}
''
