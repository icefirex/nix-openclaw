{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw";
  version = "2026.2.21";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-iV/n217XAkFaMdoYhBKoSthwmCYr2XzGcp7V4pVF008=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-jSykh7F76MxuYEVAQHXuS4ZSBQPvbFvdlKRp5L5JXj8=";
    fetcherVersion = 1;
  };

  buildPhase = ''
    runHook preBuild
    # Install UI deps first - canvas:a2ui:bundle (part of pnpm build) needs them
    pnpm ui:install
    # Symlink rolldown to node_modules/.bin so bundle-a2ui.sh finds it via command -v
    # (rolldown is a transitive dep of tsdown, not hoisted to top-level .bin)
    ROLLDOWN_BIN=$(find node_modules/.pnpm -path '*/rolldown/bin/cli.mjs' ! -path '*/rolldown-plugin-dts/*' | head -1)
    ln -sf "$(readlink -f "$ROLLDOWN_BIN")" node_modules/.bin/rolldown
    chmod +x node_modules/.bin/rolldown
    pnpm build
    # Remove temp symlink so it doesn't end up as a broken link in the output
    rm -f node_modules/.bin/rolldown
    # Build the control UI dashboard
    # Fix broken CDN logo URL - use local asset instead
    mkdir -p ui/public/assets
    cp docs/assets/pixel-lobster.svg ui/public/assets/
    sed -i 's|https://mintcdn.com/clawhub/[^"]*pixel-lobster.svg[^"]*|./assets/pixel-lobster.svg|g' ui/src/ui/app-render.ts
    pnpm ui:build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/openclaw $out/bin
    cp -r dist node_modules package.json $out/lib/openclaw/
    cp -r extensions $out/lib/openclaw/ 2>/dev/null || true
    cp -r apps $out/lib/openclaw/ 2>/dev/null || true
    cp -r skills $out/lib/openclaw/ 2>/dev/null || true
    cp -r docs $out/lib/openclaw/ 2>/dev/null || true
    # Copy the control UI dashboard (built to dist/control-ui)
    cp -r dist/control-ui $out/lib/openclaw/dist/ 2>/dev/null || true
    makeWrapper ${nodejs}/bin/node $out/bin/openclaw \
      --add-flags "$out/lib/openclaw/dist/entry.js"
    runHook postInstall
  '';

  preFixup = ''
    find $out -xtype l -delete 2>/dev/null || true
  '';

  meta = {
    homepage = "https://openclaw.ai";
    description = "AI assistant gateway for messaging platforms";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "openclaw";
  };
})
