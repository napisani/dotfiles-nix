# This file has been generated by node2nix 1.11.1. Do not edit!

{nodeEnv, fetchurl, fetchgit, nix-gitignore, stdenv, lib, globalBuildInputs ? []}:

let
  sources = {
    "@dqbd/tiktoken-1.0.15" = {
      name = "_at_dqbd_slash_tiktoken";
      packageName = "@dqbd/tiktoken";
      version = "1.0.15";
      src = fetchurl {
        url = "https://registry.npmjs.org/@dqbd/tiktoken/-/tiktoken-1.0.15.tgz";
        sha512 = "a6I67K1xUkuqcuwulobIJiLikkoE7egMaviI1Jg5bxSn2V7QGqXsGE3jTKr8UIOU/o74mAAd5TkeXFNBtaKF4A==";
      };
    };
  };
in
{
  aicommits = nodeEnv.buildNodePackage {
    name = "aicommits";
    packageName = "aicommits";
    version = "1.11.0";
    src = fetchurl {
      url = "https://registry.npmjs.org/aicommits/-/aicommits-1.11.0.tgz";
      sha512 = "YRy+M230yIuJ+j3YqXRAtAbmR2rJSzST5TbJASPXqaIh7kMN477DGQS1cwqwTJeBdMXKBJrWJAgVd//LkoA4Wg==";
    };
    dependencies = [
      sources."@dqbd/tiktoken-1.0.15"
    ];
    buildInputs = globalBuildInputs;
    meta = {
      description = "Writes your git commit messages for you with AI";
      homepage = "https://github.com/Nutlope/aicommits#readme";
      license = "MIT";
    };
    production = true;
    bypassCache = true;
    reconstructLock = true;
  };
}
