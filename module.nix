{ config, lib, pkgs, ... }:

let
  cfg = config.programs.openclaw;
  openclaw = pkgs.callPackage ./package.nix { };

  # Import skills registry
  skillsRegistry = import ./skills-registry.nix { inherit pkgs; };

  # Get list of enabled skills
  enabledSkills = lib.filterAttrs (name: skillCfg: skillCfg.enable) cfg.skills;

  # Build skills directory with all enabled skills
  skillsDir = pkgs.symlinkJoin {
    name = "openclaw-skills";
    paths = lib.mapAttrsToList (name: skillCfg:
      pkgs.runCommand "skill-${name}" {} ''
        mkdir -p $out/${name}
        cp -r ${skillsRegistry.${name}.src}/* $out/${name}/
      ''
    ) enabledSkills;
  };

  # Generate the openclaw config JSON
  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON {
    tools = ({
      exec = {
        pathPrepend = [
          "/run/current-system/sw/bin"
        ];
      };
      message.crossContext = {
        allowAcrossProviders = true;
        marker = {
          enabled = true;
          prefix = "[from {channel}] ";
        };
      };
    }) // (if cfg.whisper.enable then {
      media = {
        audio = {
          enabled = true;
          models = [{
            type = "cli";
            command = "whisper";
            args = ["--model" cfg.whisper.model "--output_format" "txt"];
            capabilities = ["audio"];
          }];
        };
      };
    } else {});
    commands = {
      restart = true;
    };
    browser = {
      enabled = true;
      executablePath = "/run/current-system/sw/bin/chromium";
      headless = true;
      noSandbox = true;
    };
    agents = {
      defaults = {
        model.primary = cfg.model;
        thinkingDefault = cfg.thinkingDefault;
        workspace = "/tmp/openclaw-workspace";
      };
      list = [{ default = true; id = "main"; }];
    };
    gateway.mode = "local";
    messages.queue = {
      byChannel = {
        discord = "queue";
        telegram = "interrupt";
        webchat = "queue";
      };
      mode = "interrupt";
    };
    channels = {
      telegram = {
        allowFrom = cfg.telegram.allowFrom;
        enabled = cfg.telegram.enable;
        groups = cfg.telegram.groups;
      };
    } // (if cfg.slack.enable then {
      slack = {
        enabled = true;
        dm.policy = cfg.slack.dmPolicy;
        groupPolicy = cfg.slack.groupPolicy;
      };
    } else {});
    plugins = {
      entries = (if cfg.telegram.enable then {
        telegram.enabled = true;
      } else {}) // (if cfg.slack.enable then {
        slack.enabled = true;
      } else {});
      slots = {};
    };
  });
in {
  options.programs.openclaw = {
    enable = lib.mkEnableOption "OpenClaw - AI assistant gateway for messaging platforms";

    model = lib.mkOption {
      type = lib.types.str;
      default = "anthropic/claude-sonnet-4";
      description = "Default AI model to use";
    };

    thinkingDefault = lib.mkOption {
      type = lib.types.str;
      default = "high";
      description = "Default thinking level";
    };

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Port for the openclaw gateway";
    };

    telegram = {
      enable = lib.mkEnableOption "Telegram integration";

      botTokenFile = lib.mkOption {
        type = lib.types.str;
        default = "telegram-bot-token";
        description = "Path to file containing Telegram bot token (relative to state dir)";
      };

      allowFrom = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "List of Telegram user IDs allowed to interact with the bot";
      };

      groups = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Telegram group configurations";
      };
    };

    slack = {
      enable = lib.mkEnableOption "Slack integration";

      appTokenFile = lib.mkOption {
        type = lib.types.str;
        default = "slack-app-token";
        description = "Path to file containing Slack app token (relative to state dir)";
      };

      botTokenFile = lib.mkOption {
        type = lib.types.str;
        default = "slack-bot-token";
        description = "Path to file containing Slack bot token (relative to state dir)";
      };

      dmPolicy = lib.mkOption {
        type = lib.types.str;
        default = "pairing";
        description = "DM policy (pairing, open)";
      };

      groupPolicy = lib.mkOption {
        type = lib.types.str;
        default = "open";
        description = "Group policy (open, allowlist, disabled)";
      };
    };

    whisper = {
      enable = lib.mkEnableOption "Local Whisper audio transcription";

      model = lib.mkOption {
        type = lib.types.str;
        default = "base";
        description = "Whisper model size (tiny, base, small, medium, large)";
      };
    };

    skills = {
      asana = {
        enable = lib.mkEnableOption "Asana integration skill";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ openclaw ]
      ++ lib.optional cfg.whisper.enable pkgs.openai-whisper;

    systemd.user.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = "%h";
        OPENCLAW_CONFIG_PATH = "%h/.openclaw/openclaw.json";
        OPENCLAW_STATE_DIR = "%h/.openclaw";
      };

      script = ''
        if [ -f "$HOME/.openclaw/${cfg.telegram.botTokenFile}" ]; then
          export TELEGRAM_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "$HOME/.openclaw/${cfg.telegram.botTokenFile}")
        fi

        GATEWAY_TOKEN="''${OPENCLAW_GATEWAY_TOKEN:-openclaw-local-$(${pkgs.inetutils}/bin/hostname)}"
        export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

        exec ${openclaw}/bin/openclaw gateway --port ${toString cfg.gatewayPort} --token "$GATEWAY_TOKEN"
      '';

      serviceConfig = {
        Type = "simple";
        ExecStartPre = pkgs.writeShellScript "openclaw-setup" ''
          set -e
          ${pkgs.coreutils}/bin/mkdir -p "$HOME/.openclaw/workspace" "$HOME/.openclaw/agents/main/sessions" "$HOME/.openclaw/credentials" "$HOME/.openclaw/skills"
          ${pkgs.coreutils}/bin/chmod 700 "$HOME/.openclaw"

          ${lib.optionalString (enabledSkills != {}) ''
            echo "Setting up openclaw skills..."
            ${pkgs.coreutils}/bin/rm -rf "$HOME/.openclaw/skills"
            ${pkgs.coreutils}/bin/mkdir -p "$HOME/.openclaw/skills"
            ${pkgs.coreutils}/bin/cp -r ${skillsDir}/* "$HOME/.openclaw/skills/" 2>/dev/null || true
            ${pkgs.coreutils}/bin/chmod -R u+w "$HOME/.openclaw/skills"
            echo "Skills installed: ${lib.concatStringsSep ", " (lib.attrNames enabledSkills)}"

            ${lib.optionalString (cfg.skills.asana.enable or false) ''
              if [ ! -f "$HOME/.openclaw/asana/token.json" ]; then
                echo ""
                echo "Asana skill requires OAuth setup!"
                echo "   Run: node ~/.openclaw/skills/asana/scripts/configure.mjs --client-id YOUR_ID --client-secret YOUR_SECRET"
                echo "   Then: node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs authorize"
                echo ""
              fi
            ''}
          ''}

          ${pkgs.gnused}/bin/sed 's|/tmp/openclaw-workspace|'"$HOME"'/.openclaw/workspace|g' ${configFile} > "$HOME/.openclaw/openclaw.json"

          TOKEN_FILE="$HOME/.openclaw/${cfg.telegram.botTokenFile}"
          if [ -f "$TOKEN_FILE" ]; then
            TOKEN=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")
            ${pkgs.jq}/bin/jq --arg token "$TOKEN" '.channels.telegram.botToken = $token' \
              "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
            ${pkgs.coreutils}/bin/mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"
          fi

          SLACK_APP_TOKEN_FILE="$HOME/.openclaw/${cfg.slack.appTokenFile}"
          SLACK_BOT_TOKEN_FILE="$HOME/.openclaw/${cfg.slack.botTokenFile}"
          if [ -f "$SLACK_APP_TOKEN_FILE" ] && [ -f "$SLACK_BOT_TOKEN_FILE" ]; then
            SLACK_APP_TOKEN=$(${pkgs.coreutils}/bin/cat "$SLACK_APP_TOKEN_FILE")
            SLACK_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "$SLACK_BOT_TOKEN_FILE")
            ${pkgs.jq}/bin/jq --arg appToken "$SLACK_APP_TOKEN" --arg botToken "$SLACK_BOT_TOKEN" \
              '.channels.slack.appToken = $appToken | .channels.slack.botToken = $botToken' \
              "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
            ${pkgs.coreutils}/bin/mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"
          fi

          GATEWAY_TOKEN="openclaw-local-$(${pkgs.inetutils}/bin/hostname)"
          ${pkgs.jq}/bin/jq --arg token "$GATEWAY_TOKEN" '.gateway.auth.token = $token | .gateway.remote.token = $token' \
            "$HOME/.openclaw/openclaw.json" > "$HOME/.openclaw/openclaw.json.tmp"
          ${pkgs.coreutils}/bin/mv "$HOME/.openclaw/openclaw.json.tmp" "$HOME/.openclaw/openclaw.json"

          ${pkgs.coreutils}/bin/chmod 600 "$HOME/.openclaw/openclaw.json"
        '';
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}
