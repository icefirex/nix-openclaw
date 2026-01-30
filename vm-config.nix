# VM Image Configuration for nixos-generators
#
# This configuration is used to generate VM images (QCOW2, ISO, VMware, etc.)
# Hardware and boot configuration is handled by the generator.

{ config, pkgs, lib, ... }:

{
  # ===================
  # Network
  # ===================
  networking.hostName = "openclaw-server";
  networking.networkmanager.enable = true;

  # Firewall - allow Cockpit and OpenClaw gateway
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22     # SSH
      9090   # Cockpit
      18789  # OpenClaw gateway
    ];
  };

  # ===================
  # Timezone & Locale
  # ===================
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # ===================
  # Users
  # ===================
  users.users.admin = {
    isNormalUser = true;
    description = "Admin";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";  # Change this after first login!
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here before building:
      # "ssh-ed25519 AAAAC3..."
    ];
  };

  # ===================
  # Services
  # ===================

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;  # Set to false after adding SSH keys
    };
  };

  # Cockpit - Web-based server management
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        AllowUnencrypted = false;
      };
    };
  };

  # ===================
  # Secrets
  # ===================
  # Create these files after first boot:
  #   /run/secrets/zai-api-key
  #   /run/secrets/telegram-bot-token
  systemd.tmpfiles.rules = [
    "d /run/secrets 0700 root root -"
  ];

  # ===================
  # OpenClaw
  # ===================
  programs.openclaw = {
    enable = true;

    # AI Model - format: provider/model-name
    model = "zai/glm-4.7";
    thinkingDefault = "high";
    gatewayPort = 18789;

    # Secrets - map env var names to file paths
    # Create these files after first boot
    secrets = {
      ZAI_API_KEY = "/run/secrets/zai-api-key";
      # Add more providers as needed:
      # ANTHROPIC_API_KEY = "/run/secrets/anthropic";
      # OPENAI_API_KEY = "/run/secrets/openai";
    };

    # Telegram
    telegram = {
      enable = true;
      botTokenFile = "/run/secrets/telegram-bot-token";
      allowFrom = [
        # Add your Telegram user ID(s) here before building:
        # 123456789
      ];
    };

    # Whisper - voice message transcription
    whisper = {
      enable = true;
      model = "base";  # tiny, base, small, medium, large
    };

    # Slack (optional)
    # slack = {
    #   enable = true;
    #   appTokenFile = "/run/secrets/slack-app-token";
    #   botTokenFile = "/run/secrets/slack-bot-token";
    # };
  };

  # ===================
  # System Packages
  # ===================
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    jq
  ];

  # ===================
  # Nix Settings
  # ===================
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
