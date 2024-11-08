final: prev: {
  vi-mongo = prev.stdenv.mkDerivation rec {
    pname = "vi-mongo";
    version = "0.1.17";

    src = prev.fetchurl {
      url =
        "https://github.com/kopecmaciej/vi-mongo/releases/download/v${version}/vi-mongo_Darwin_x86_64.tar.gz";
      sha256 =
        "sha256-tDqo5/yApls50ktGHaGELqW10C0YclzgN6cf1TgUjuw="; 
    };

    # No need for unpacking phase, as we'll do it manually in installPhase
    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      tar -xzf $src
      chmod +x vi-mongo
      mv vi-mongo $out/bin/
    '';

    meta = with prev.lib; {
      description = "vi-mongo application";
      homepage = "https://github.com/kopecmaciej/vi-mongo";
      license = licenses.unfree; # Adjust if you know the correct license
      platforms = platforms.darwin;
      maintainers = with maintainers; [ ]; # Add maintainers if applicable
    };
  };
}

