# Minimal NixOS configuration with OpenClaw
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "openclaw-vm";
  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  users.users.demo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # Create secrets directory
  systemd.tmpfiles.rules = [
    "d /run/secrets 0700 root root -"
  ];

  # OpenClaw
  programs.openclaw = {
    enable = true;

    model = "zai/glm-4.7";

    # Generic secrets - works with any provider
    secrets = {
      ZAI_API_KEY = "/run/secrets/zai-api-key";
      # Add more as needed:
      # ANTHROPIC_API_KEY = "/run/secrets/anthropic";
      # OPENAI_API_KEY = "/run/secrets/openai";
    };

    telegram = {
      enable = true;
      botTokenFile = "/run/secrets/telegram-bot-token";
      allowFrom = [
        # Your Telegram user ID
      ];
    };

    whisper = {
      enable = true;
      model = "base";
    };
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "24.11";
}
