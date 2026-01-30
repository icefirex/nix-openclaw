# nix-openclaw

NixOS module for [OpenClaw](https://openclaw.ai) - AI assistant gateway for messaging platforms.

## Features

- Declarative NixOS configuration via `programs.openclaw`
- Systemd user service for the gateway
- Telegram and Slack integration
- Optional Whisper audio transcription
- Skills registry (Asana, etc.)

## Installation

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openclaw.url = "github:icefirex/nix-openclaw";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, openclaw, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        openclaw.nixosModules.openclaw
        ./configuration.nix
      ];
    };
  };
}
```

## Configuration

```nix
{ config, pkgs, ... }:

{
  programs.openclaw = {
    enable = true;

    # AI model (default: anthropic/claude-sonnet-4)
    model = "anthropic/claude-sonnet-4";
    thinkingDefault = "high";

    # Gateway port (default: 18789)
    gatewayPort = 18789;

    # Telegram integration
    telegram = {
      enable = true;
      allowFrom = [ 123456789 ]; # Your Telegram user ID
    };

    # Slack integration (optional)
    # slack.enable = true;

    # Whisper audio transcription (optional)
    # whisper.enable = true;
    # whisper.model = "base";

    # Skills
    # skills.asana.enable = true;
  };
}
```

## Setup

After enabling, create the bot token file:

```bash
mkdir -p ~/.openclaw
echo "YOUR_TELEGRAM_BOT_TOKEN" > ~/.openclaw/telegram-bot-token
chmod 600 ~/.openclaw/telegram-bot-token
```

The gateway starts automatically as a systemd user service:

```bash
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway -f
```

## Example

See the `example/` directory for a minimal VM configuration.

## License

MIT
