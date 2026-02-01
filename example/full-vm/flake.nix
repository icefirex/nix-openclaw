# Full VM Example: Ready-to-run NixOS VM with OpenClaw
#
# Usage:
#   1. Copy this directory
#   2. Generate hardware config: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
#   3. Create secrets (for production, use agenix instead - see README):
#      sudo mkdir -p /run/secrets
#      echo "your-api-key" | sudo tee /run/secrets/zai-api-key
#      echo "your-telegram-token" | sudo tee /run/secrets/telegram-bot-token
#      head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32 | sudo tee /run/secrets/gateway-token
#      sudo chmod 600 /run/secrets/*
#   4. Edit configuration.nix (set your Telegram user ID, hostname, etc.)
#   5. Deploy: sudo nixos-rebuild switch --flake .#openclaw-server
#
# After deployment:
#   - Cockpit web UI: https://<your-ip>:9090
#   - OpenClaw dashboard: ssh -L 18789:127.0.0.1:18789 admin@<your-ip>
#     then open http://localhost:18789/?token=YOUR_GATEWAY_TOKEN

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
