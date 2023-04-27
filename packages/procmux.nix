{ stdenv, lib, pkgs }:
let 

  ptterm = pkgs.python39Packages.buildPythonApplication rec {
  version = "0.2";
  pname = "ptterm";
  src = pkgs.python39Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-pPhG+/XZ8wKlRCyGB9KbMb6rCK23KrNGBQhafFXrEXo=";
  };
  /* src = pkgs.fetchFromGitHub({ */
  /*   owner = "napisani"; */
  /*   repo = "procmux"; */
  /*   rev = "ceb93ffa551b91ff19d4eb95bfbb030d300ef973"; */
  /*   hash = "sha256-Uerv3Dg84jAHhySh86OZi7mgOaS3SWwWzNQcatymvqc="; */
  /* }); */
  doCheck = false;
  pythonImportCheck = [ "ptterm" ];
  nativeBuildInputs = [ 
    pkgs.python39Packages.setuptools 
    pkgs.python39Packages.prompt_toolkit
    pkgs.python39Packages.pyte
    pkgs.python39Packages.six
  ];
};
in
pkgs.python39Packages.buildPythonApplication rec {
  version = "1.0.10";
  pname = "procmux";
  src = pkgs.python39Packages.fetchPypi {
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
    pkgs.python39Packages.setuptools 
    pkgs.python39Packages.jinja2
    pkgs.python39Packages.attrs
    pkgs.python39Packages.pyparsing
    pkgs.python39Packages.six
    pkgs.python39Packages.pyte
    pkgs.python39Packages.py
    pkgs.python39Packages.tomli
    pkgs.python39Packages.packaging
    pkgs.python39Packages.hiyapyco
    pkgs.python39Packages.pluggy
    ptterm
  ];
}
