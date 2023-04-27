pkgs.python3Packages.buildPythonApplication rec {
  version = "1.0.10";
  name = "procmux"
  src = pkgs.fetchFromGitHub({
    owner = "napisani";
    repo = "procmux";
    rev = "ceb93ffa551b91ff19d4eb95bfbb030d300ef973";
    hash = "sha256-Uerv3Dg84jAHhySh86OZi7mgOaS3SWwWzNQcatymvqc=";
  });

  /* postPatch = '' */
  /*   substituteInPlace lib/indicator_sound_switcher/lib_pulseaudio.py \ */
  /*     --replace "CDLL('libpulse.so.0')" "CDLL('${libpulseaudio}/lib/libpulse.so')" */
  /* ''; */

  /* nativeBuildInputs = [ */
  /*   gettext */
  /*   intltool */
  /*   wrapGAppsHook */
  /*   glib */
  /*   gdk-pixbuf */
  /* ]; */

  /* buildInputs = [ */
  /*   librsvg */
  /* ]; */

  /* propagatedBuildInputs = [ */
  /*   python3Packages.setuptools */
  /*   python3Packages.pygobject3 */
  /*   gtk3 */
  /*   gobject-introspection */
  /*   librsvg */
  /*   libayatana-appindicator */
  /*   libpulseaudio */
  /*   keybinder3 */
  /* ]; */

  /* meta = with lib; { */
  /*   description = "Sound input/output selector indicator for Linux"; */
  /*   homepage = "https://yktoo.com/en/software/sound-switcher-indicator/"; */
  /*   license = licenses.gpl3Plus; */
  /*   maintainers = with maintainers; [ alexnortung ]; */
  /*   platforms = [ "x86_64-linux" ]; */
  /* }; */
}
