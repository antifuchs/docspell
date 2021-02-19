{ pkgs ? import <nixpkgs> { }
, elmPackages ? pkgs.elmPackages
, jdk11 ? pkgs.jdk11
, makeWrapper ? pkgs.makeWrapper
, nodePackages ? pkgs.nodePackages
, nodejs ? pkgs.nodejs
, sbt ? pkgs.sbt
}: pkgs.stdenv.mkDerivation {
  pname = "docspell-git";
  version = "0.20.0-dev";

  src = ./..;

  nativeBuildInputs = [ jdk11 nodePackages.npm sbt nodejs elmPackages.elm makeWrapper ];

  buildPhase = ''
    mkdir ./.sbt ./.cache
    export HOME=`pwd`/.sbt
    export COURSIER_CACHE=`pwd`/.cache
    sbt -Dsbt.global.base=./.sbt/ -Dsbt.ivy.home=./.sbt -Divy.home=./.sbt make-zip ';' make-tools
  '';

  installPhase = ''
    mkdir $out
    install ./modules/restserver/target/universal/docspell-restserver-*.zip $out/restserver.zip
    install ./modules/joex/target/universal/docspell-joex-*.zip $out/joex.zip
    install ./tools/target/docspell-tools-*.zip $out/tools.zip
  '';
}
