# Example: Minimal NixOS configuration using nix-openclaw
#
# Usage:
#   1. Copy this directory to your VM or use it as a reference
#   2. Generate hardware config: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#   3. Edit configuration.nix with your settings
#   4. Deploy: sudo nixos-rebuild switch --flake .#openclaw-vm

{
  description = "NixOS with OpenClaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Import the openclaw module
    # After pushing to GitHub, change this to:
    # openclaw.url = "github:YOUR_USERNAME/nix-openclaw";
    openclaw.url = "path:../";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, openclaw }:
  {
    nixosConfigurations.openclaw-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the openclaw module
        openclaw.nixosModules.openclaw

        # Your VM configuration
        ./configuration.nix
      ];
    };
  };
}
