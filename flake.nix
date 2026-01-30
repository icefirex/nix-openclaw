{
  description = "OpenClaw - AI assistant gateway for messaging platforms";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    # NixOS module - import this in your configuration
    nixosModules = {
      default = self.nixosModules.openclaw;
      openclaw = import ./module.nix;
    };

    # Standalone package
    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = self.packages.${system}.openclaw;
        openclaw = pkgs.callPackage ./package.nix { };
      }
    );

    # Overlay for adding openclaw to pkgs
    overlays.default = final: prev: {
      openclaw = self.packages.${prev.system}.openclaw;
    };
  };
}
