{ lib, pkgs }:
let
  plan = import ../mods/internal/operation-plan.nix { inherit lib; };
  fails = ops: !(builtins.tryEval (builtins.deepSeq (plan ops) true)).success;
in
assert plan { } == [ ];
assert
  plan {
    z = { };
    a = {
      after = [ "z" ];
    };
    b = {
      after = [ "z" ];
    };
  } == [
    "z"
    "a"
    "b"
  ];
assert
  plan {
    z = { };
    a = { };
  } == [
    "a"
    "z"
  ];
assert fails { a.after = [ "typo" ]; };
assert fails { a.after = [ "a" ]; };
assert fails {
  a.after = [ "b" ];
  b.after = [ "a" ];
};
pkgs.runCommand "operation-plan" { } ''touch "$out"''
