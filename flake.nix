{
  description = "Assist in organizing your piles of documents, resulting from scanners, e-mails and other sources with miminal effort.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { flake-utils, nixpkgs, self, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      packageHelper = import ./nix/pkg.nix;
      sourcePackages = pkgs.callPackage (import ./nix/release.nix).currentPkg { };
    in
    {
      packages = sourcePackages;

      overlay = final: prev: { docspell = sourcePackages; };

      nixosModules = (import ./nix/release.nix).modules ++ [
        { nixpkgs.overlays = [ self.overlay.${system} ]; }
      ];

      apps = {
        repl =
          flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "repl" ''
              confnix=$(mktemp)
              echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
              trap "rm $confnix" EXIT
              nix repl $confnix
            '';
          };
      };
    });
}
