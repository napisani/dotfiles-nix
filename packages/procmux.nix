{ stdenv, lib, pkgs }:
pkgs.python3Packages.buildPythonApplication rec {
  version = "1.0.10";
  pname = "procmux";
  src = pkgs.python3Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-IHKCfi+L4BnTzr/KjT+ZacS8oGoSI9rQIytNbxff040=";
  };
  /* src = pkgs.fetchFromGitHub({ */
  /*   owner = "napisani"; */
  /*   repo = "procmux"; */
  /*   rev = "ceb93ffa551b91ff19d4eb95bfbb030d300ef973"; */
  /*   hash = "sha256-Uerv3Dg84jAHhySh86OZi7mgOaS3SWwWzNQcatymvqc="; */
  /* }); */
  doCheck = false;
  pythonImportCheck = [ "procmux" ];
  nativeBuildInputs = [ 
    pkgs.python3Packages.setuptools 
    /* pkgs.python3Packages.jinja2 */
    /* pkgs.python3Packages.attrs */
    /* pkgs.python3Packages.pyparsing */
    /* pkgs.python3Packages.six */
    /* pkgs.python3Packages.pyte */
    /* pkgs.python3Packages.py */
    /* pkgs.python3Packages.tomli */
    /* pkgs.python3Packages.packaging */
    /* pkgs.python3Packages.hiyapyco */
    /* pkgs.python3Packages.pluggy */
    /* pkgs.python3Packages.pluggy */
  ];
}
