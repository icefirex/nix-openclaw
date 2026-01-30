# Minimal NixOS configuration with OpenClaw
{ config, pkgs, ... }:

{
  imports = [
    # Include your hardware configuration
    # Generate with: sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
    ./hardware-configuration.nix
  ];

  # Boot loader (adjust for your VM)
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda"; # Adjust to your disk

  # Network
  networking.hostName = "openclaw-vm";
  networking.networkmanager.enable = true;

  # Enable SSH for remote access
  services.openssh.enable = true;

  # Create a user
  users.users.demo = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # Set a password or use SSH keys
    initialPassword = "changeme";
  };

  # Enable OpenClaw
  programs.openclaw = {
    enable = true;

    # AI model configuration
    model = "anthropic/claude-sonnet-4";
    thinkingDefault = "high";

    # Gateway port (default: 18789)
    gatewayPort = 18789;

    # Telegram integration (optional)
    telegram = {
      enable = true;
      # List of Telegram user IDs allowed to use the bot
      allowFrom = [
        # Add your Telegram user ID here
        # 123456789
      ];
    };

    # Slack integration (optional)
    # slack.enable = true;

    # Whisper audio transcription (optional)
    # whisper.enable = true;
    # whisper.model = "base";

    # Skills (optional)
    # skills.asana.enable = true;
  };

  # Allow unfree packages (for some dependencies)
  nixpkgs.config.allowUnfree = true;

  # System state version
  system.stateVersion = "24.11";
}
