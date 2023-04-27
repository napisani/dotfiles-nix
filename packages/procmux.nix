{ stdenv, lib, pkgs, mach-nix }:
mach-nix.buildPythonApplication {
  src = builtins.fetchGit({
    url = "https://github.com/napisani/procmux";
    ref = "main";
  });
}

/* pkgs.python3Packages.buildPythonApplication rec { */
/*   version = "1.0.10"; */
/*   pname = "procmux"; */
/*   src = pkgs.python3Packages.fetchPypi { */
/*     inherit pname version; */
/*     hash = "sha256-IHKCfi+L4BnTzr/KjT+ZacS8oGoSI9rQIytNbxff040="; */
/*   }; */
/*   src = pkgs.fetchFromGitHub({ */
/*     owner = "napisani"; */
/*     repo = "procmux"; */
/*     rev = "ceb93ffa551b91ff19d4eb95bfbb030d300ef973"; */
/*     hash = "sha256-Uerv3Dg84jAHhySh86OZi7mgOaS3SWwWzNQcatymvqc="; */
/*   }); */
/*   doCheck = false; */
/*   pythonImportCheck = [ "procmux" ]; */
/*   nativeBuildInputs = [ */ 
/*     pkgs.python3Packages.setuptools */ 
/*     /1* pkgs.python3Packages.jinja2 *1/ */
/*     /1* pkgs.python3Packages.attrs *1/ */
/*     /1* pkgs.python3Packages.pyparsing *1/ */
/*     /1* pkgs.python3Packages.six *1/ */
/*     /1* pkgs.python3Packages.pyte *1/ */
/*     /1* pkgs.python3Packages.py *1/ */
/*     /1* pkgs.python3Packages.tomli *1/ */
/*     /1* pkgs.python3Packages.packaging *1/ */
/*     /1* pkgs.python3Packages.hiyapyco *1/ */
/*     /1* pkgs.python3Packages.pluggy *1/ */
/*     /1* pkgs.python3Packages.pluggy *1/ */
/*   /1* ]; *1/ */
/*   /1* postPatch = '' *1/ */
/*   /1*   substituteInPlace lib/indicator_sound_switcher/lib_pulseaudio.py \ *1/ */
/*   /1*     --replace "CDLL('libpulse.so.0')" "CDLL('${libpulseaudio}/lib/libpulse.so')" *1/ */
/*   /1* ''; *1/ */

/*   /1* nativeBuildInputs = [ *1/ */
/*   /1*   gettext *1/ */
/*   /1*   intltool *1/ */
/*   /1*   wrapGAppsHook *1/ */
/*   /1*   glib *1/ */
/*   /1*   gdk-pixbuf *1/ */
/*   /1* ]; *1/ */

/*   /1* buildInputs = [ *1/ */
/*   /1*   librsvg *1/ */
/*   /1* ]; *1/ */

/*   /1* propagatedBuildInputs = [ *1/ */
/*   /1*   python3Packages.setuptools *1/ */
/*   /1*   python3Packages.pygobject3 *1/ */
/*   /1*   gtk3 *1/ */
/*   /1*   gobject-introspection *1/ */
/*   /1*   librsvg *1/ */
/*   /1*   libayatana-appindicator *1/ */
/*   /1*   libpulseaudio *1/ */
/*   /1*   keybinder3 *1/ */
/*   /1* ]; *1/ */

/*   /1* meta = with lib; { *1/ */
/*   /1*   description = "Sound input/output selector indicator for Linux"; *1/ */
/*   /1*   homepage = "https://yktoo.com/en/software/sound-switcher-indicator/"; *1/ */
/*   /1*   license = licenses.gpl3Plus; *1/ */
/*   /1*   maintainers = with maintainers; [ alexnortung ]; *1/ */
/*   /1*   platforms = [ "x86_64-linux" ]; *1/ */
/*   /1* }; *1/ */
/* } */
