# OpenClaw Skills Registry
# Pinned versions of skills from ClawdHub for reproducible builds
#
# To add a new skill:
# 1. Download: curl -L "https://clawdhub.com/api/v1/download?slug=SKILL_NAME" -o skill.zip
# 2. Get hash: nix hash file skill.zip
# 3. Add entry below

{ pkgs }:

{
  asana = {
    name = "asana";
    version = "1.0.0";
    description = "Asana integration via REST API with OAuth support";
    src = pkgs.stdenv.mkDerivation {
      name = "asana-skill-src";
      src = pkgs.fetchurl {
        url = "https://clawdhub.com/api/v1/download?slug=asana";
        sha256 = "sha256-gTA/ZZ8X+5l5LxhNkdwCwxMepT45FqwBAlbgKT4Yo0g=";
      };
      nativeBuildInputs = [ pkgs.unzip ];
      unpackPhase = "unzip $src";
      installPhase = "mkdir -p $out && cp -r * $out/";
    };
    setupInstructions = ''
      Asana OAuth Setup Required:
      1. Create an Asana app at https://app.asana.com/0/developer-console
      2. Enable scopes: tasks:read, tasks:write, projects:read
      3. Set redirect URI: urn:ietf:wg:oauth:2.0:oob
      4. Run: node ~/.openclaw/skills/asana/scripts/configure.mjs --client-id "YOUR_ID" --client-secret "YOUR_SECRET"
      5. Run: node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs authorize
      6. Open the URL, authorize, copy the code
      7. Run: node ~/.openclaw/skills/asana/scripts/oauth_oob.mjs token --code "YOUR_CODE"
    '';
  };

  brave-images = {
    name = "brave-images";
    version = "1.0.1";
    description = "Search for images using Brave Search API";
    src = pkgs.stdenv.mkDerivation {
      name = "brave-images-skill-src";
      src = pkgs.fetchurl {
        url = "https://clawhub.ai/api/v1/download?slug=brave-images";
        sha256 = "sha256-yc0GGnewaUtxBR8P48kEnjk68zu8o+ofyxSmbvCSldA=";
      };
      nativeBuildInputs = [ pkgs.unzip ];
      unpackPhase = "unzip $src";
      installPhase = "mkdir -p $out && cp -r * $out/";
    };
    setupInstructions = ''
      Requires BRAVE_API_KEY environment variable (already configured via secrets).
    '';
  };

  # Template for adding more skills:
  # skillName = {
  #   name = "skillName";
  #   version = "x.y.z";
  #   description = "What this skill does";
  #   src = pkgs.fetchzip {
  #     url = "https://clawdhub.com/api/v1/download?slug=skillName";
  #     sha256 = "sha256-HASH";
  #     stripRoot = false;
  #   };
  #   setupInstructions = "Any manual setup needed";
  # };
}
