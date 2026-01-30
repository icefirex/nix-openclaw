# Full VM Example: Ready-to-run NixOS VM with OpenClaw
#
# Usage:
#   1. Copy this directory
#   2. Generate hardware config: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#   3. Create secrets:
#      sudo mkdir -p /run/secrets
#      echo "your-api-key" | sudo tee /run/secrets/zai-api-key
#      echo "your-telegram-token" | sudo tee /run/secrets/telegram-bot-token
#      sudo chmod 600 /run/secrets/*
#   4. Edit configuration.nix (set your Telegram user ID, hostname, etc.)
#   5. Deploy: sudo nixos-rebuild switch --flake .#openclaw-server
#
# After deployment:
#   - Cockpit web UI: https://<your-ip>:9090
#   - OpenClaw gateway: http://<your-ip>:18789

{
  description = "Full NixOS VM with OpenClaw and Cockpit";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    openclaw.url = "github:icefirex/nix-openclaw";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, openclaw }:
  {
    nixosConfigurations.openclaw-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        openclaw.nixosModules.openclaw
        ./configuration.nix
      ];
    };
  };
}
