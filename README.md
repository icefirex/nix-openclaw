<p align="center">
  <img align="middle" src="https://brand.nixos.org/logos/nixos-logo-default-gradient-white-regular-horizontal-recommended.svg" height="130" alt="NixOS"><img align="middle" alt="+" src="https://img.icons8.com/ios-filled/50/FFFFFF/plus-math.png" height="35">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img align="middle" src="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text.png" height="80" alt="OpenClaw">
</p>

# nix-openclaw

NixOS module for [OpenClaw](https://openclaw.ai) - AI assistant gateway for messaging platforms.

## Features

- Fully declarative NixOS configuration via `programs.openclaw`
- Systemd user service for the gateway
- Telegram and Slack integration
- Optional Whisper audio transcription
- Skills registry (Asana, etc.)
- Generic secrets management (works with any provider, sops-nix, agenix, or manual)
- Pre-built VM images (QCOW2, ISO, VMware, VirtualBox, Proxmox)

## Quick Start: VM Images

Build a ready-to-run VM image directly from the flake:

```bash
# QCOW2 - For QEMU/KVM/Proxmox
nix build github:icefirex/nix-openclaw#qcow

# ISO - Bootable installer
nix build github:icefirex/nix-openclaw#iso

# VMware
nix build github:icefirex/nix-openclaw#vmware

# VirtualBox
nix build github:icefirex/nix-openclaw#virtualbox

# Proxmox LXC container
nix build github:icefirex/nix-openclaw#proxmox-lxc
```

After booting, create your secrets and configure:

```bash
# Login: admin / changeme
sudo mkdir -p /run/secrets
echo "your-api-key" | sudo tee /run/secrets/zai-api-key
echo "your-telegram-token" | sudo tee /run/secrets/telegram-bot-token
sudo chmod 600 /run/secrets/*

# Edit /etc/nixos/configuration.nix to set your Telegram user ID
sudo nixos-rebuild switch
```

The VM includes Cockpit (web UI on port 9090), SSH, and OpenClaw with Telegram and Whisper.

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

All secrets are referenced by file path. Just point to your secret files and rebuild.

```nix
{ config, pkgs, ... }:

{
  programs.openclaw = {
    enable = true;

    # AI model (format: provider/model-name)
    model = "zai/glm-4.7";

    # Secrets - map any env var to a secret file
    secrets = {
      ZAI_API_KEY = "/run/secrets/zai-api-key";
    };

    # Telegram integration
    telegram = {
      enable = true;
      botTokenFile = "/run/secrets/telegram-bot-token";
      allowFrom = [ 123456789 ]; # Your Telegram user ID
    };

    # Whisper audio transcription (optional)
    whisper = {
      enable = true;
      model = "base";
    };
  };
}
```

## Secrets

The `secrets` option is a generic attribute set that maps environment variable names to secret file paths. This works with any provider - just use the correct env var name:

```nix
secrets = {
  # Common providers
  ANTHROPIC_API_KEY = "/run/secrets/anthropic";
  OPENAI_API_KEY = "/run/secrets/openai";
  ZAI_API_KEY = "/run/secrets/zai";
  GROQ_API_KEY = "/run/secrets/groq";
  GEMINI_API_KEY = "/run/secrets/gemini";

  # Any other env var your setup needs
  CUSTOM_API_KEY = "/run/secrets/custom";
};
```

### Manual Setup

```bash
sudo mkdir -p /run/secrets
echo "your-api-key" | sudo tee /run/secrets/zai-api-key
echo "123456:ABC-token" | sudo tee /run/secrets/telegram-bot-token
sudo chmod 600 /run/secrets/*
```

---

<details>
<summary><h2>Using with sops-nix</h2></summary>

```nix
{ config, ... }:

{
  sops.secrets = {
    zai-api-key = {};
    telegram-bot-token = {};
  };

  programs.openclaw = {
    enable = true;
    model = "zai/glm-4.7";

    secrets = {
      ZAI_API_KEY = config.sops.secrets.zai-api-key.path;
    };

    telegram = {
      enable = true;
      botTokenFile = config.sops.secrets.telegram-bot-token.path;
      allowFrom = [ 123456789 ];
    };
  };
}
```

</details>

<details>
<summary><h2>Using with agenix</h2></summary>

```nix
{ config, ... }:

{
  age.secrets = {
    zai-api-key.file = ../secrets/zai-api-key.age;
    telegram-bot-token.file = ../secrets/telegram-bot-token.age;
  };

  programs.openclaw = {
    enable = true;
    model = "zai/glm-4.7";

    secrets = {
      ZAI_API_KEY = config.age.secrets.zai-api-key.path;
    };

    telegram = {
      enable = true;
      botTokenFile = config.age.secrets.telegram-bot-token.path;
      allowFrom = [ 123456789 ];
    };
  };
}
```

</details>

<details>
<summary><h2>Slack Integration</h2></summary>

```nix
programs.openclaw = {
  enable = true;

  slack = {
    enable = true;
    appTokenFile = "/run/secrets/slack-app-token";
    botTokenFile = "/run/secrets/slack-bot-token";
    dmPolicy = "pairing";
    groupPolicy = "open";
  };
};
```

### Setup

1. Create a Slack App at https://api.slack.com/apps
2. Enable Socket Mode and get an **App-Level Token** (`xapp-...`)
3. Add Bot Token Scopes: `app_mentions:read`, `chat:write`, `im:history`, `im:read`, `im:write`
4. Install the app and get the **Bot Token** (`xoxb-...`)
5. Save both tokens to your secret files

</details>

<details>
<summary><h2>Whisper Audio Transcription</h2></summary>

```nix
programs.openclaw = {
  enable = true;

  whisper = {
    enable = true;
    model = "base";  # tiny, base, small, medium, large
  };
};
```

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| tiny | ~75MB | Fastest | Lower |
| base | ~150MB | Fast | Good |
| small | ~500MB | Medium | Better |
| medium | ~1.5GB | Slow | High |
| large | ~3GB | Slowest | Highest |

</details>

<details>
<summary><h2>Asana Integration</h2></summary>

```nix
programs.openclaw = {
  enable = true;
  skills.asana.enable = true;
};
```

After rebuild, run the OAuth setup:

```bash
node ~/.openclaw/skills/asana/scripts/configure.mjs --client-id "ID" --client-secret "SECRET"
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs authorize
# Follow URL, get code
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs token --code "CODE"
systemctl --user restart openclaw-gateway
```

</details>

---

## All Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable OpenClaw |
| `model` | string | `"anthropic/claude-sonnet-4"` | AI model (provider/model-name) |
| `thinkingDefault` | string | `"high"` | Default thinking level |
| `gatewayPort` | int | `18789` | Gateway port |
| `stateDir` | string | `".openclaw"` | State directory (relative to HOME) |
| `secrets` | attrsOf path | `{}` | Map of env var names to secret file paths |
| `telegram.enable` | bool | `false` | Enable Telegram |
| `telegram.botTokenFile` | path | required | Path to bot token file |
| `telegram.allowFrom` | list of int | `[]` | Allowed user IDs |
| `slack.enable` | bool | `false` | Enable Slack |
| `slack.appTokenFile` | path | required | Path to app token file |
| `slack.botTokenFile` | path | required | Path to bot token file |
| `whisper.enable` | bool | `false` | Enable Whisper |
| `whisper.model` | enum | `"base"` | Model size |
| `skills.asana.enable` | bool | `false` | Enable Asana skill |

---

## Troubleshooting

```bash
# Check service
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway -f

# Check config
cat ~/.openclaw/openclaw.json | jq .
```

## Examples

The `example/` directory contains reference configurations:

- **`example/`** - Minimal OpenClaw options to add to an existing NixOS config
- **`example/full-vm/`** - Complete VM configuration for manual NixOS installs (includes QEMU guest agent, Cockpit, etc.)

## License

[MIT](LICENSE)
