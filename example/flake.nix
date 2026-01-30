# Example: NixOS configuration using nix-openclaw
#
# Usage:
#   1. Copy this directory or use as reference
#   2. Generate hardware config: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#   3. Edit configuration.nix with your settings
#   4. Deploy: sudo nixos-rebuild switch --flake .#myhost

{
  description = "NixOS with OpenClaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    openclaw.url = "github:icefirex/nix-openclaw";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, openclaw }:
  {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        openclaw.nixosModules.openclaw
        ./configuration.nix
      ];
    };
  };
}
