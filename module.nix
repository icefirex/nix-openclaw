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
    # Configure Z.AI provider with correct base URL
    models = {
      providers = {
        zai = {
          baseUrl = "https://api.z.ai/api/paas/v4";
          apiKey = "ZAI_API_KEY";
          models = [];
        };
      };
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

  # Generate exports for all secrets
  secretExports = lib.concatStringsSep "\n" (lib.mapAttrsToList (envVar: secretPath: ''
    if [ -f "${secretPath}" ]; then
      export ${envVar}=$(${pkgs.coreutils}/bin/cat "${secretPath}")
    fi
  '') cfg.secrets);

in {
  options.programs.openclaw = {
    enable = lib.mkEnableOption "OpenClaw - AI assistant gateway for messaging platforms";

    model = lib.mkOption {
      type = lib.types.str;
      default = "anthropic/claude-sonnet-4";
      description = "Default AI model to use (format: provider/model-name)";
      example = "zai/glm-4.7";
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

    # Generic secrets configuration
    secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      description = ''
        Attribute set mapping environment variable names to secret file paths.
        Each secret file will be read and exported as the corresponding env var.
      '';
      example = lib.literalExpression ''
        {
          ANTHROPIC_API_KEY = "/run/secrets/anthropic-api-key";
          ZAI_API_KEY = "/run/secrets/zai-api-key";
          OPENAI_API_KEY = "/run/secrets/openai-api-key";
        }
      '';
    };

    telegram = {
      enable = lib.mkEnableOption "Telegram integration";

      botTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Absolute path to file containing Telegram bot token";
        example = "/run/secrets/telegram-bot-token";
      };

      allowFrom = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "List of Telegram user IDs allowed to interact with the bot";
        example = [ 123456789 ];
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
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Absolute path to file containing Slack app token (xapp-...)";
        example = "/run/secrets/slack-app-token";
      };

      botTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Absolute path to file containing Slack bot token (xoxb-...)";
        example = "/run/secrets/slack-bot-token";
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
        type = lib.types.enum [ "tiny" "base" "small" "medium" "large" ];
        default = "base";
        description = "Whisper model size";
      };
    };

    skills = {
      asana = {
        enable = lib.mkEnableOption "Asana integration skill";
      };
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = ".openclaw";
      description = "State directory relative to HOME";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run the openclaw service as (required)";
      example = "alice";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group to run the openclaw service as";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assertions for required options
    assertions = [
      {
        assertion = cfg.telegram.enable -> cfg.telegram.botTokenFile != null;
        message = "programs.openclaw.telegram.botTokenFile must be set when Telegram is enabled";
      }
      {
        assertion = cfg.slack.enable -> (cfg.slack.appTokenFile != null && cfg.slack.botTokenFile != null);
        message = "programs.openclaw.slack.appTokenFile and botTokenFile must be set when Slack is enabled";
      }
    ];

    environment.systemPackages = [ openclaw ]
      ++ lib.optional cfg.whisper.enable pkgs.openai-whisper;

    # System service running as specified user (not a user service)
    systemd.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = "/home/${cfg.user}";
        OPENCLAW_CONFIG_PATH = "/home/${cfg.user}/${cfg.stateDir}/openclaw.json";
        OPENCLAW_STATE_DIR = "/home/${cfg.user}/${cfg.stateDir}";
      };

      script = ''
        # Load all secrets as environment variables
        ${secretExports}

        # Load Telegram bot token
        ${lib.optionalString (cfg.telegram.enable && cfg.telegram.botTokenFile != null) ''
          if [ -f "${cfg.telegram.botTokenFile}" ]; then
            export TELEGRAM_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.telegram.botTokenFile}")
          fi
        ''}

        # Load Slack tokens
        ${lib.optionalString (cfg.slack.enable && cfg.slack.appTokenFile != null) ''
          if [ -f "${cfg.slack.appTokenFile}" ]; then
            export SLACK_APP_TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.slack.appTokenFile}")
          fi
        ''}
        ${lib.optionalString (cfg.slack.enable && cfg.slack.botTokenFile != null) ''
          if [ -f "${cfg.slack.botTokenFile}" ]; then
            export SLACK_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.slack.botTokenFile}")
          fi
        ''}

        GATEWAY_TOKEN="''${OPENCLAW_GATEWAY_TOKEN:-openclaw-local-$(${pkgs.inetutils}/bin/hostname)}"
        export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

        exec ${openclaw}/bin/openclaw gateway --port ${toString cfg.gatewayPort} --token "$GATEWAY_TOKEN"
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;

        # Kill any zombie openclaw process holding the port before starting
        # The "+" prefix runs as root so it can kill processes owned by any user
        ExecStartPre = [
          "+${pkgs.writeShellScript "openclaw-kill-zombie" ''
            # Find process holding port ${toString cfg.gatewayPort}
            PORT_PID=$(${pkgs.lsof}/bin/lsof -ti tcp:${toString cfg.gatewayPort} 2>/dev/null || true)
            if [ -n "$PORT_PID" ]; then
              # Only kill if it's an openclaw process (safety check)
              PROC_NAME=$(${pkgs.procps}/bin/ps -p "$PORT_PID" -o comm= 2>/dev/null || true)
              if [ "$PROC_NAME" = "openclaw" ] || [ "$PROC_NAME" = "openclaw-gate" ] || [ "$PROC_NAME" = "node" ]; then
                echo "Killing stale openclaw process $PORT_PID ($PROC_NAME) holding port ${toString cfg.gatewayPort}"
                kill -9 $PORT_PID 2>/dev/null || true
                sleep 1
              else
                echo "Warning: Port ${toString cfg.gatewayPort} held by non-openclaw process $PORT_PID ($PROC_NAME), not killing"
              fi
            fi
          ''}"
          (pkgs.writeShellScript "openclaw-setup" ''
            set -e
            STATE_DIR="/home/${cfg.user}/${cfg.stateDir}"

            ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR/workspace" "$STATE_DIR/agents/main/sessions" "$STATE_DIR/credentials" "$STATE_DIR/skills"
            ${pkgs.coreutils}/bin/chmod 700 "$STATE_DIR"

            ${lib.optionalString (enabledSkills != {}) ''
              echo "Setting up openclaw skills..."
              ${pkgs.coreutils}/bin/rm -rf "$STATE_DIR/skills"
              ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR/skills"
              ${pkgs.coreutils}/bin/cp -r ${skillsDir}/* "$STATE_DIR/skills/" 2>/dev/null || true
              ${pkgs.coreutils}/bin/chmod -R u+w "$STATE_DIR/skills"
              echo "Skills installed: ${lib.concatStringsSep ", " (lib.attrNames enabledSkills)}"

              ${lib.optionalString (cfg.skills.asana.enable or false) ''
                if [ ! -f "$STATE_DIR/asana/token.json" ]; then
                  echo ""
                  echo "Asana skill requires OAuth setup!"
                  echo "   Run: node $STATE_DIR/skills/asana/scripts/configure.mjs --client-id YOUR_ID --client-secret YOUR_SECRET"
                  echo "   Then: node $STATE_DIR/skills/asana/scripts/oauth_oob.mjs authorize"
                  echo ""
                fi
              ''}
            ''}

            # Generate config with workspace path fixed
            ${pkgs.gnused}/bin/sed 's|/tmp/openclaw-workspace|'"$STATE_DIR"'/workspace|g' ${configFile} > "$STATE_DIR/openclaw.json"

            # Inject Telegram bot token into config
            ${lib.optionalString (cfg.telegram.enable && cfg.telegram.botTokenFile != null) ''
              if [ -f "${cfg.telegram.botTokenFile}" ]; then
                TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.telegram.botTokenFile}")
                ${pkgs.jq}/bin/jq --arg token "$TOKEN" '.channels.telegram.botToken = $token' \
                  "$STATE_DIR/openclaw.json" > "$STATE_DIR/openclaw.json.tmp"
                ${pkgs.coreutils}/bin/mv "$STATE_DIR/openclaw.json.tmp" "$STATE_DIR/openclaw.json"
              fi
            ''}

            # Inject Slack tokens into config
            ${lib.optionalString (cfg.slack.enable && cfg.slack.appTokenFile != null && cfg.slack.botTokenFile != null) ''
              if [ -f "${cfg.slack.appTokenFile}" ] && [ -f "${cfg.slack.botTokenFile}" ]; then
                SLACK_APP_TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.slack.appTokenFile}")
                SLACK_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "${cfg.slack.botTokenFile}")
                ${pkgs.jq}/bin/jq --arg appToken "$SLACK_APP_TOKEN" --arg botToken "$SLACK_BOT_TOKEN" \
                  '.channels.slack.appToken = $appToken | .channels.slack.botToken = $botToken' \
                  "$STATE_DIR/openclaw.json" > "$STATE_DIR/openclaw.json.tmp"
                ${pkgs.coreutils}/bin/mv "$STATE_DIR/openclaw.json.tmp" "$STATE_DIR/openclaw.json"
              fi
            ''}

            # Inject gateway token
            GATEWAY_TOKEN="openclaw-local-$(${pkgs.inetutils}/bin/hostname)"
            ${pkgs.jq}/bin/jq --arg token "$GATEWAY_TOKEN" '.gateway.auth.token = $token | .gateway.remote.token = $token' \
              "$STATE_DIR/openclaw.json" > "$STATE_DIR/openclaw.json.tmp"
            ${pkgs.coreutils}/bin/mv "$STATE_DIR/openclaw.json.tmp" "$STATE_DIR/openclaw.json"

            ${pkgs.coreutils}/bin/chmod 600 "$STATE_DIR/openclaw.json"
          '')
        ];

        # Ensure clean shutdown - kill any stale openclaw child processes
        # The "+" prefix runs as root so it can kill processes owned by any user
        ExecStopPost = "+${pkgs.writeShellScript "openclaw-cleanup" ''
          # Find process holding port ${toString cfg.gatewayPort}
          PORT_PID=$(${pkgs.lsof}/bin/lsof -ti tcp:${toString cfg.gatewayPort} 2>/dev/null || true)
          if [ -n "$PORT_PID" ]; then
            # Only kill if it's an openclaw process (safety check)
            PROC_NAME=$(${pkgs.procps}/bin/ps -p "$PORT_PID" -o comm= 2>/dev/null || true)
            if [ "$PROC_NAME" = "openclaw" ] || [ "$PROC_NAME" = "openclaw-gate" ] || [ "$PROC_NAME" = "node" ]; then
              echo "Cleaning up stale openclaw process $PORT_PID ($PROC_NAME) holding port ${toString cfg.gatewayPort}"
              kill -9 $PORT_PID 2>/dev/null || true
            fi
          fi
        ''}";

        # Restart configuration with limits to prevent infinite crash loops
        Restart = "on-failure";
        RestartSec = "10s";
      };

      # Restart limits: max 5 attempts within 5 minutes before giving up
      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 300;
      };
    };
  };
}
