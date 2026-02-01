# Example NixOS configuration with OpenClaw
#
# This shows only the OpenClaw-specific parts.
# Add these to your existing configuration.nix

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Your existing boot/network/user config here...
  # boot.loader.systemd-boot.enable = true;
  # networking.hostName = "myhost";
  # users.users.myuser = { ... };

  # Create secrets directory (or use sops-nix/agenix - recommended for production)
  # Generate gateway token: head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32
  systemd.tmpfiles.rules = [
    "d /run/secrets 0700 root root -"
  ];

  # OpenClaw configuration
  programs.openclaw = {
    enable = true;
    user = "myuser";  # Required: user to run the service as

    # Model format: provider/model-name
    model = "zai/glm-4.7";

    # Dashboard authentication (create /run/secrets/gateway-token)
    gatewayTokenFile = "/run/secrets/gateway-token";

    # Secrets - map env var names to secret file paths
    secrets = {
      ZAI_API_KEY = "/run/secrets/zai-api-key";
      # ANTHROPIC_API_KEY = "/run/secrets/anthropic";
      # OPENAI_API_KEY = "/run/secrets/openai";
    };

    # Telegram
    telegram = {
      enable = true;
      botTokenFile = "/run/secrets/telegram-bot-token";
      allowFrom = [
        # Your Telegram user ID(s)
      ];
    };

    # Optional: Whisper for voice transcription
    whisper = {
      enable = true;
      model = "base";
    };

    # Optional: Slack
    # slack = {
    #   enable = true;
    #   appTokenFile = "/run/secrets/slack-app-token";
    #   botTokenFile = "/run/secrets/slack-bot-token";
    # };
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.11";
}
