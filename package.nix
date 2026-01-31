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
  version = "2026.1.30";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-L/AUBlpOGf1Hy+OyFE0xXqTTDyfppMckNzHBp7HvKN4=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-oMj8MPH41jXvbtVGth/DbQYHf0B33I92ZJYXP1+lUcc=";
    fetcherVersion = 1;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
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
