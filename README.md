<p align="center">
  <img align="middle" src="https://brand.nixos.org/logos/nixos-logo-default-gradient-white-regular-horizontal-recommended.svg" height="130" alt="NixOS"><img align="middle" alt="+" src="https://img.icons8.com/ios-filled/50/FFFFFF/plus-math.png" height="35">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img align="middle" src="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text.png" height="80" alt="OpenClaw">
</p>

# nix-openclaw

NixOS module for [OpenClaw](https://openclaw.ai) - AI assistant gateway for messaging platforms.

## Features

- Fully declarative NixOS configuration via `programs.openclaw`
- Systemd service running as configurable user (secure by default)
- **Control UI Dashboard** - Web interface for monitoring and management
- Telegram and Slack integration
- Optional Whisper audio transcription
- Skills registry (Asana, etc.)
- Generic secrets management (works with any provider, sops-nix, agenix, or manual)
- Secure gateway token authentication (supports agenix/sops-nix)
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

After booting, set up your secrets using agenix (recommended) or manually for testing:

```bash
# Login: admin / changeme

# For production: use agenix (see "Using with agenix" section below)
# For quick testing only:
sudo mkdir -p /run/secrets
echo "your-api-key" | sudo tee /run/secrets/zai-api-key
echo "your-telegram-token" | sudo tee /run/secrets/telegram-bot-token
head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32 | sudo tee /run/secrets/gateway-token
sudo chmod 600 /run/secrets/*

# Edit /etc/nixos/configuration.nix:
#   - Set programs.openclaw.user = "admin";
#   - Set programs.openclaw.gatewayTokenFile = "/run/secrets/gateway-token";
#   - Set your Telegram user ID in telegram.allowFrom
sudo nixos-rebuild switch
```

> **Note:** Manual secrets in `/run/secrets/` are lost on reboot. For persistent, secure secrets, use agenix as documented below.

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
    user = "myuser";  # Required: user to run the service as

    # AI model (format: provider/model-name)
    model = "zai/glm-4.7";

    # Secrets - map any env var to a secret file
    secrets = {
      ZAI_API_KEY = "/run/secrets/zai-api-key";
    };

    # Secure gateway token for dashboard authentication (recommended)
    gatewayTokenFile = "/run/secrets/gateway-token";

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

## Control UI Dashboard

OpenClaw includes a web-based dashboard for monitoring and managing your gateway. By default, it binds to localhost only for security.

### Accessing the Dashboard

The dashboard requires authentication via a gateway token. Access it securely via SSH tunnel:

```bash
# Create SSH tunnel (run on your local machine)
ssh -L 18789:127.0.0.1:18789 user@your-server

# Then open in browser:
# http://localhost:18789/?token=YOUR_GATEWAY_TOKEN
```

### Gateway Token Security

By default, a weak token is generated (`openclaw-local-hostname`). For production, use a secure random token via `gatewayTokenFile`:

```nix
programs.openclaw = {
  enable = true;
  user = "myuser";
  gatewayTokenFile = "/run/secrets/gateway-token";  # 32+ char random string
};
```

Generate a secure token:
```bash
head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32
```

---

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
    gateway-token = {};
  };

  programs.openclaw = {
    enable = true;
    user = "myuser";
    model = "zai/glm-4.7";
    gatewayTokenFile = config.sops.secrets.gateway-token.path;

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
<summary><h2>Using with agenix (Recommended)</h2></summary>

Agenix encrypts secrets with age, using SSH keys for decryption. Secrets are decrypted at system activation and stored in `/run/agenix/`.

### Step 1: Create secrets.nix

Define which keys can decrypt each secret:

```nix
# secrets/secrets.nix
let
  # Your server's SSH host key (get with: ssh-keyscan your-server 2>/dev/null | grep ed25519)
  server = "ssh-ed25519 AAAAC3...your-server-host-key";

  # Your personal SSH key (for local encryption)
  admin = "ssh-ed25519 AAAAC3...your-personal-key";
in
{
  "zai-api-key.age".publicKeys = [ server admin ];
  "telegram-bot-token.age".publicKeys = [ server admin ];
  "gateway-token.age".publicKeys = [ server admin ];
}
```

### Step 2: Encrypt secrets

```bash
cd secrets/

# Create and encrypt API key
echo "your-zai-api-key" > /tmp/zai-key
age -R <(echo "ssh-ed25519 AAAAC3...server-key") \
    -R <(echo "ssh-ed25519 AAAAC3...admin-key") \
    -o zai-api-key.age /tmp/zai-key
rm /tmp/zai-key

# Create and encrypt Telegram token
echo "123456:ABC-your-bot-token" > /tmp/tg-token
age -R <(echo "ssh-ed25519 AAAAC3...server-key") \
    -R <(echo "ssh-ed25519 AAAAC3...admin-key") \
    -o telegram-bot-token.age /tmp/tg-token
rm /tmp/tg-token

# Create and encrypt gateway token (generate random)
head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32 > /tmp/gw-token
age -R <(echo "ssh-ed25519 AAAAC3...server-key") \
    -R <(echo "ssh-ed25519 AAAAC3...admin-key") \
    -o gateway-token.age /tmp/gw-token
cat /tmp/gw-token  # Save this for dashboard access!
rm /tmp/gw-token
```

### Step 3: Configure NixOS

```nix
{ config, ... }:

{
  # Tell agenix where to find the host's private key
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    zai-api-key = {
      file = ./secrets/zai-api-key.age;
      owner = "myuser";
      mode = "0400";
    };
    telegram-bot-token = {
      file = ./secrets/telegram-bot-token.age;
      owner = "myuser";
      mode = "0400";
    };
    gateway-token = {
      file = ./secrets/gateway-token.age;
      owner = "myuser";
      mode = "0400";
    };
  };

  programs.openclaw = {
    enable = true;
    user = "myuser";
    model = "zai/glm-4.7";
    gatewayTokenFile = config.age.secrets.gateway-token.path;

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

### Security Notes

- **Never commit unencrypted secrets** - Only `.age` files should be in git
- **Use the server's host key** - This ensures only that specific server can decrypt
- **Add your admin key** - So you can re-encrypt or update secrets locally
- **Secrets go to `/run/agenix/`** - A tmpfs, never written to disk unencrypted

</details>

<details>
<summary><h2>Slack Integration</h2></summary>

```nix
programs.openclaw = {
  enable = true;
  user = "myuser";

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
  user = "myuser";

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
  user = "myuser";
  skills.asana.enable = true;
};
```

After rebuild, run the OAuth setup:

```bash
node ~/.openclaw/skills/asana/scripts/configure.mjs --client-id "ID" --client-secret "SECRET"
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs authorize
# Follow URL, get code
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs token --code "CODE"
sudo systemctl restart openclaw-gateway
```

</details>

---

## All Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable OpenClaw |
| `user` | string | **required** | User to run the service as |
| `group` | string | `"users"` | Group to run the service as |
| `model` | string | `"anthropic/claude-sonnet-4"` | AI model (provider/model-name) |
| `thinkingDefault` | string | `"high"` | Default thinking level |
| `gatewayPort` | int | `18789` | Gateway port (binds to localhost) |
| `gatewayTokenFile` | path | `null` | Path to file with dashboard auth token |
| `stateDir` | string | `".openclaw"` | State directory (relative to HOME) |
| `secrets` | attrsOf path | `{}` | Map of env var names to secret file paths |
| `telegram.enable` | bool | `false` | Enable Telegram |
| `telegram.botTokenFile` | path | required | Path to bot token file |
| `telegram.allowFrom` | list of int | `[]` | Allowed user IDs |
| `telegram.groups` | attrs | `{}` | Telegram group configurations |
| `slack.enable` | bool | `false` | Enable Slack |
| `slack.appTokenFile` | path | required | Path to app token file |
| `slack.botTokenFile` | path | required | Path to bot token file |
| `slack.dmPolicy` | string | `"pairing"` | DM policy (pairing, open) |
| `slack.groupPolicy` | string | `"open"` | Group policy (open, allowlist, disabled) |
| `whisper.enable` | bool | `false` | Enable Whisper |
| `whisper.model` | enum | `"base"` | Model size (tiny, base, small, medium, large) |
| `skills.asana.enable` | bool | `false` | Enable Asana skill |

---

## Troubleshooting

```bash
# Check service status
sudo systemctl status openclaw-gateway

# View logs
sudo journalctl -u openclaw-gateway -f

# Check config (replace 'myuser' with your configured user)
sudo cat /home/myuser/.openclaw/openclaw.json | jq .

# Restart service
sudo systemctl restart openclaw-gateway

# Check if port is listening
ss -tlnp | grep 18789
```

### Common Issues

**Service fails to start with port in use:**
The service automatically kills stale openclaw processes on the configured port. If issues persist, manually check: `lsof -i :18789`

**Dashboard shows "unauthorized":**
Ensure you're using the correct token in the URL: `http://localhost:18789/?token=YOUR_TOKEN`

**Secrets not loading:**
Check that secret files exist and have correct permissions (should be readable by the configured user).

## Security

OpenClaw follows a **zero-trust security model** by default:

- **Service isolation** - Runs as a dedicated user (not root)
- **Localhost binding** - Gateway only listens on 127.0.0.1, not exposed to network
- **Token authentication** - Dashboard requires a secret token
- **Encrypted secrets** - Supports agenix/sops-nix for encrypted secret storage
- **Automatic cleanup** - Safely terminates stale processes on restart

### Zero-Trust: Keep the Dashboard Local

> **⚠️ Do not expose the dashboard port to the network.**

The gateway intentionally binds to `127.0.0.1` only. This is by design. Even with token authentication, exposing the dashboard port to the internet or local network is **strongly discouraged**:

- Tokens can be leaked, brute-forced, or intercepted
- The dashboard provides full control over your AI gateway
- Network exposure increases attack surface unnecessarily

**Always access the dashboard via SSH tunnel.** SSH provides:
- Strong authentication (keys, not just tokens)
- Encrypted transport
- No additional open ports
- Audit trail of who connected

If you need remote access, SSH is already available and battle-tested. Adding another exposed port with weaker authentication defeats the purpose of defense in depth.

### Recommended Setup

1. Use `gatewayTokenFile` with agenix for secure dashboard authentication
2. **Never** open port 18789 in your firewall
3. **Never** modify the gateway to bind to `0.0.0.0`
4. Access dashboard only via SSH tunnel: `ssh -L 18789:127.0.0.1:18789 user@server`
5. Store all API keys in encrypted secret files

---

## Examples

The `example/` directory contains reference configurations:

- **`example/`** - Minimal OpenClaw options to add to an existing NixOS config
- **`example/full-vm/`** - Complete VM configuration for manual NixOS installs (includes QEMU guest agent, Cockpit, etc.)

## License

[MIT](LICENSE)
