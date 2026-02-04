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
  version = "2026.2.2";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-b4n/ZIXNMqrR7wIipHgvKX+gWAdj6kCq4wEMcgsVILc=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-mVxlV9xFwKnmj89fObw8vLITnWQzIRopHyr8quqnSAQ=";
    fetcherVersion = 1;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    # Build the control UI dashboard
    # Fix broken CDN logo URL - use local asset instead
    mkdir -p ui/public/assets
    cp docs/assets/pixel-lobster.svg ui/public/assets/
    sed -i 's|https://mintcdn.com/clawhub/[^"]*pixel-lobster.svg[^"]*|./assets/pixel-lobster.svg|g' ui/src/ui/app-render.ts
    pnpm ui:install
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
