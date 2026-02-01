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

  # Firewall - SSH and Cockpit only
  # OpenClaw dashboard is intentionally NOT exposed (zero-trust)
  # Access it via SSH tunnel: ssh -L 18789:127.0.0.1:18789 admin@server
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22     # SSH
      9090   # Cockpit
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
  #   /run/secrets/gateway-token (generate with: head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)
  #
  # For production, use agenix instead of manual /run/secrets (see README)
  systemd.tmpfiles.rules = [
    "d /run/secrets 0700 root root -"
  ];

  # ===================
  # OpenClaw
  # ===================
  programs.openclaw = {
    enable = true;
    user = "admin";  # Run service as this user

    # AI Model - format: provider/model-name
    model = "zai/glm-4.7";
    thinkingDefault = "high";
    gatewayPort = 18789;

    # Dashboard authentication token
    # Create /run/secrets/gateway-token after first boot
    gatewayTokenFile = "/run/secrets/gateway-token";

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
