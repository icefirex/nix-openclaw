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

---

## AI Models

OpenClaw supports multiple AI providers. The model format is `provider/model-name`.

### Supported Providers

| Provider | Model Format | API Key Environment Variable |
|----------|--------------|------------------------------|
| Anthropic | `anthropic/claude-sonnet-4`, `anthropic/claude-opus-4-5` | `ANTHROPIC_API_KEY` |
| OpenAI | `openai/gpt-4o`, `openai/gpt-4-turbo` | `OPENAI_API_KEY` |
| Z.AI | `zai/glm-4.7` | `ZAI_API_KEY` |
| Groq | `groq/llama-3.3-70b` | `GROQ_API_KEY` |
| Google | `google/gemini-2.0-flash` | `GEMINI_API_KEY` |

### Setting up API Keys

API keys should be set as environment variables for the systemd user service:

```bash
# Create the environment.d directory
mkdir -p ~/.config/environment.d

# Add your API key (example for Anthropic)
echo 'ANTHROPIC_API_KEY=sk-ant-your-key-here' > ~/.config/environment.d/openclaw.conf
chmod 600 ~/.config/environment.d/openclaw.conf

# Reload and restart
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

You can add multiple API keys to the same file:

```bash
cat > ~/.config/environment.d/openclaw.conf << 'EOF'
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-xxx
ZAI_API_KEY=xxx.xxx
EOF
chmod 600 ~/.config/environment.d/openclaw.conf
```

### Example: Using Z.AI

```nix
programs.openclaw = {
  enable = true;
  model = "zai/glm-4.7";
  # ...
};
```

---

<details>
<summary><h2>Slack Integration</h2></summary>

### Configuration

```nix
programs.openclaw = {
  enable = true;

  slack = {
    enable = true;
    dmPolicy = "pairing";    # "pairing" or "open"
    groupPolicy = "open";    # "open", "allowlist", or "disabled"
  };
};
```

### Setup

1. Create a Slack App at https://api.slack.com/apps

2. Enable Socket Mode and get an **App-Level Token** (starts with `xapp-`)

3. Add Bot Token Scopes:
   - `app_mentions:read`
   - `chat:write`
   - `im:history`
   - `im:read`
   - `im:write`

4. Install the app to your workspace and get the **Bot Token** (starts with `xoxb-`)

5. Save the tokens:

```bash
mkdir -p ~/.openclaw
echo "xapp-your-app-token" > ~/.openclaw/slack-app-token
echo "xoxb-your-bot-token" > ~/.openclaw/slack-bot-token
chmod 600 ~/.openclaw/slack-*-token
```

6. Restart the gateway:

```bash
systemctl --user restart openclaw-gateway
```

</details>

<details>
<summary><h2>Whisper Audio Transcription</h2></summary>

Enable local audio transcription using OpenAI Whisper:

### Configuration

```nix
programs.openclaw = {
  enable = true;

  whisper = {
    enable = true;
    model = "base";  # Options: tiny, base, small, medium, large
  };
};
```

### Model Sizes

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| tiny | ~75MB | Fastest | Lower |
| base | ~150MB | Fast | Good |
| small | ~500MB | Medium | Better |
| medium | ~1.5GB | Slow | High |
| large | ~3GB | Slowest | Highest |

The model downloads automatically on first use. For VMs or systems with limited resources, `tiny` or `base` is recommended.

### Usage

Send voice messages to your Telegram bot - they will be automatically transcribed using Whisper before being processed by the AI.

</details>

<details>
<summary><h2>Asana Integration</h2></summary>

The Asana skill allows OpenClaw to manage your Asana tasks.

### Configuration

```nix
programs.openclaw = {
  enable = true;

  skills.asana.enable = true;
};
```

### OAuth Setup

1. Create an Asana app at https://app.asana.com/0/developer-console

2. Configure the app:
   - Enable scopes: `tasks:read`, `tasks:write`, `projects:read`
   - Set redirect URI: `urn:ietf:wg:oauth:2.0:oob`

3. Configure the skill with your credentials:

```bash
node ~/.openclaw/skills/asana/scripts/configure.mjs \
  --client-id "YOUR_CLIENT_ID" \
  --client-secret "YOUR_CLIENT_SECRET"
```

4. Start the OAuth flow:

```bash
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs authorize
```

5. Open the URL in your browser, authorize the app, and copy the code

6. Exchange the code for a token:

```bash
node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs token --code "YOUR_CODE"
```

7. Restart the gateway:

```bash
systemctl --user restart openclaw-gateway
```

### Usage

You can now ask OpenClaw to:
- "Show my Asana tasks"
- "Create a task: Review PR #123"
- "Mark task X as complete"

</details>

---

## Example

See the `example/` directory for a minimal VM configuration.

## Troubleshooting

### Check service status

```bash
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway -f
```

### Check configuration

```bash
cat ~/.openclaw/openclaw.json | jq .
```

### Common issues

- **"Missing workspace template"**: Update the flake to get the latest package with docs included
- **Model warnings**: Ensure model format is `provider/model-name` (e.g., `zai/glm-4.7` not just `z.ai`)
- **API key not found**: Check `~/.config/environment.d/` files and restart the service

## License

MIT
