# One validated, deterministic execution plan for CLI and activation. `after`
# means ordering, not a success prerequisite; independent failures stay isolated.
{ lib }:
operations:
let
  names = builtins.attrNames operations;
  after = name: operations.${name}.after or [ ];
  invalid = lib.concatMap (
    name:
    map (dependency: "${name} -> ${dependency}") (
      builtins.filter (dependency: dependency == name || !builtins.hasAttr dependency operations) (
        after name
      )
    )
  ) names;
  sorted = lib.toposort (a: b: builtins.elem a (after b)) names;
in
if invalid != [ ] then
  throw "global-tools: unknown or self dependency: ${lib.concatStringsSep ", " invalid}"
else if sorted ? cycle then
  throw "global-tools: dependency cycle: ${lib.concatStringsSep " -> " sorted.cycle}"
else
  sorted.result
